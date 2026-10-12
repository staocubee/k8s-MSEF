#!/usr/bin/env python3
"""
MSEF Kubernetes Runtime Evaluation & Response (KRE) controller.

Receives Falco/Falcosidekick alerts over HTTP and executes containment.

Modes (KRE_MODE):
  async (default) - enqueue the alert, return 202, contain in a worker thread
  sync            - contain inside the HTTP request, return 200 when done
                    (used as the C4 synchronous baseline in the ablation study)

Every alert that reaches the controller produces exactly one audit record,
including alerts that are debounced, out of scope, unsupported or dropped,
so that RRSR and event-loss can be computed from the audit log alone.

Timestamps (all epoch seconds, wall clock):
  falco_time      - Falco event time (from the alert payload, if present)
  t_received      - alert accepted by the HTTP handler
  t_dequeued      - worker started processing (== t_received in sync mode)
  t_actions_done  - all containment API calls returned
  t_confirmed     - containment state confirmed via the API (or null)
MTTC is defined as t_confirmed - t_received.
"""

import hashlib
import json
import logging
import os
import sys
import threading
import time
from datetime import datetime, timezone
from queue import Empty, Full, Queue

from flask import Flask, jsonify, request
from kubernetes import client, config
from kubernetes.client.rest import ApiException

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
AUDIT_LOG_FILE = os.getenv("KRE_AUDIT_LOG", "/data/results/remediation-events.jsonl")
KRE_MODE = os.getenv("KRE_MODE", "async").lower()
NUM_WORKERS = int(os.getenv("KRE_WORKER_THREADS", "4"))
QUEUE_MAXSIZE = int(os.getenv("KRE_QUEUE_MAXSIZE", "10000"))
DEBOUNCE_WINDOW_SEC = float(os.getenv("KRE_DEBOUNCE_WINDOW", "3.0"))
CONFIRM_TIMEOUT_SEC = float(os.getenv("KRE_CONFIRM_TIMEOUT", "30"))
CONFIRM_POLL_SEC = float(os.getenv("KRE_CONFIRM_POLL", "0.1"))
# Namespaces KRE is allowed to act on. Alerts from any other namespace are
# audited as "out_of_scope" and never remediated.
TARGET_NAMESPACES = {
    ns.strip() for ns in os.getenv("KRE_TARGET_NAMESPACES", "hardened").split(",") if ns.strip()
}
QUARANTINE_LABEL = "msef.security/quarantine-id"
# Only rules with this prefix are remediated. Falco's default rules are also
# forwarded by Falcosidekick and must never trigger containment.
RULE_PREFIX = os.getenv("KRE_RULE_PREFIX", "MSEF ")

if KRE_MODE not in ("async", "sync"):
    raise SystemExit(f"Invalid KRE_MODE={KRE_MODE!r}; expected 'async' or 'sync'")

logging.basicConfig(
    level=LOG_LEVEL,
    format="%(asctime)s [%(levelname)s] [KRE] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("kre")

# ---------------------------------------------------------------------------
# Kubernetes clients
# ---------------------------------------------------------------------------
try:
    config.load_incluster_config()
except Exception:  # pragma: no cover - local development only
    config.load_kube_config()

core_v1 = client.CoreV1Api()
networking_v1 = client.NetworkingV1Api()
rbac_v1 = client.RbacAuthorizationV1Api()

# ---------------------------------------------------------------------------
# Audit log
# ---------------------------------------------------------------------------
_audit_lock = threading.Lock()


def _iso(ts):
    return None if ts is None else datetime.fromtimestamp(ts, tz=timezone.utc).isoformat()


def write_audit(record: dict) -> None:
    record.setdefault("kre_mode", KRE_MODE)
    record["logged_at"] = _iso(time.time())
    line = json.dumps(record, sort_keys=True)
    try:
        os.makedirs(os.path.dirname(AUDIT_LOG_FILE), exist_ok=True)
        with _audit_lock, open(AUDIT_LOG_FILE, "a") as f:
            f.write(line + "\n")
    except OSError as e:
        # Never crash the controller because the volume is unavailable;
        # the record is still emitted on stdout.
        logger.error(f"audit write failed: {e}")
    logger.info(f"AUDIT {line}")


# ---------------------------------------------------------------------------
# Containment actions
# ---------------------------------------------------------------------------
def quarantine_pod_network(namespace: str, pod_name: str, pod_uid: str) -> dict:
    """Label the single target pod with a unique id, then deny all its traffic."""
    qid = (pod_uid or hashlib.sha256(pod_name.encode()).hexdigest())[:12]
    try:
        core_v1.patch_namespaced_pod(
            name=pod_name, namespace=namespace,
            body={"metadata": {"labels": {QUARANTINE_LABEL: qid}}},
        )
    except ApiException as e:
        if e.status != 404:
            return {"action": "quarantine", "ok": False, "error": f"label patch: {e.status} {e.reason}"}
    policy_name = f"msef-quarantine-{qid}"
    netpol = client.V1NetworkPolicy(
        metadata=client.V1ObjectMeta(
            name=policy_name, namespace=namespace,
            labels={"msef.security/quarantine": "true"},
        ),
        spec=client.V1NetworkPolicySpec(
            pod_selector=client.V1LabelSelector(match_labels={QUARANTINE_LABEL: qid}),
            policy_types=["Ingress", "Egress"], ingress=[], egress=[],
        ),
    )
    try:
        networking_v1.create_namespaced_network_policy(namespace=namespace, body=netpol)
        return {"action": "quarantine", "ok": True, "policy": policy_name}
    except ApiException as e:
        if e.status == 409:
            return {"action": "quarantine", "ok": True, "policy": policy_name, "note": "already_exists"}
        return {"action": "quarantine", "ok": False, "error": f"{e.status} {e.reason}"}


def terminate_pod(namespace: str, pod_name: str) -> dict:
    try:
        core_v1.delete_namespaced_pod(name=pod_name, namespace=namespace, grace_period_seconds=0)
        return {"action": "terminate", "ok": True}
    except ApiException as e:
        if e.status == 404:
            return {"action": "terminate", "ok": True, "note": "already_absent"}
        return {"action": "terminate", "ok": False, "error": f"{e.status} {e.reason}"}


def revoke_service_account(namespace: str, sa_name: str) -> dict:
    """
    Remove the identity's namespaced permissions.

    RBAC is additive, so access cannot be revoked by adding a binding. Instead
    this deletes every RoleBinding in the namespace whose subjects include the
    service account (recording what was removed, for restoration), and reports
    ClusterRoleBindings that reference it without modifying them.
    Bound projected tokens are invalidated when the pod is deleted, so this
    action is always combined with terminate_pod.
    """
    if not sa_name:
        return {"action": "revoke_sa", "ok": False, "error": "service account unknown"}
    removed, cluster_refs = [], []
    try:
        for rb in rbac_v1.list_namespaced_role_binding(namespace).items:
            for s in rb.subjects or []:
                if s.kind == "ServiceAccount" and s.name == sa_name and (s.namespace or namespace) == namespace:
                    rbac_v1.delete_namespaced_role_binding(rb.metadata.name, namespace)
                    removed.append({"name": rb.metadata.name, "role_ref": rb.role_ref.name})
                    break
        for crb in rbac_v1.list_cluster_role_binding().items:
            for s in crb.subjects or []:
                if s.kind == "ServiceAccount" and s.name == sa_name and s.namespace == namespace:
                    cluster_refs.append(crb.metadata.name)
                    break
    except ApiException as e:
        return {"action": "revoke_sa", "ok": False, "error": f"{e.status} {e.reason}",
                "removed_rolebindings": removed}
    return {"action": "revoke_sa", "ok": True, "removed_rolebindings": removed,
            "clusterrolebindings_not_modified": cluster_refs}


# ---------------------------------------------------------------------------
# Confirmation (state verified via the API, independent of action return codes)
# ---------------------------------------------------------------------------
def confirm_pod_absent(namespace, pod_name, pod_uid):
    deadline = time.time() + CONFIRM_TIMEOUT_SEC
    while time.time() < deadline:
        try:
            p = core_v1.read_namespaced_pod(name=pod_name, namespace=namespace)
            if pod_uid and p.metadata.uid != pod_uid:
                return time.time()  # same name, new object: original pod is gone
        except ApiException as e:
            if e.status == 404:
                return time.time()
        time.sleep(CONFIRM_POLL_SEC)
    return None


def confirm_netpol_present(namespace, policy_name):
    try:
        networking_v1.read_namespaced_network_policy(name=policy_name, namespace=namespace)
        return time.time()
    except ApiException:
        return None


# ---------------------------------------------------------------------------
# Decision matrix: explicit rule -> plan map from ConfigMap kre-config
# ---------------------------------------------------------------------------
PLAN_STEPS = {
    "TERMINATE": ("terminate",),
    "QUARANTINE_TERMINATE": ("quarantine", "terminate"),
    "QUARANTINE_REVOKE_TERMINATE": ("quarantine", "revoke_sa", "terminate"),
}


def load_rule_plans() -> dict:
    """Explicit rule -> plan map from the kre-config ConfigMap (env KRE_RULE_PLANS).
    Fails fast on a missing or invalid map: KRE must never guess a plan."""
    raw = os.getenv("KRE_RULE_PLANS")
    if not raw:
        raise SystemExit("KRE_RULE_PLANS is not set (expected from ConfigMap kre-config)")
    plans = json.loads(raw)
    bad = {r: p for r, p in plans.items() if p not in PLAN_STEPS}
    if bad:
        raise SystemExit(f"KRE_RULE_PLANS has unknown plans: {bad}")
    return plans


RULE_PLANS = load_rule_plans()


def plan_for(rule: str):
    name = RULE_PLANS.get(rule)
    return (name, PLAN_STEPS[name]) if name else (None, ())


def remediate(event: dict) -> dict:
    """Execute and confirm containment for one alert. Returns the audit record."""
    t_dequeued = time.time()
    rule = event.get("rule", "")
    of = event.get("output_fields") or {}
    namespace = of.get("k8s.ns.name") or event.get("namespace") or ""
    pod_name = of.get("k8s.pod.name") or event.get("pod") or ""
    rec = {
        "status": "processed", "falco_rule": rule, "falco_time": event.get("time"),
        "target_namespace": namespace, "target_pod": pod_name,
        "t_received": event["_t_received"], "t_dequeued": t_dequeued,
        "queue_wait_seconds": round(t_dequeued - event["_t_received"], 6),
    }
    plan_name, steps = plan_for(rule)
    rec["action_taken"] = plan_name
    if plan_name is None:
        rec.update(status="unsupported_rule", success=False)
        return rec

    pod_uid, sa_name = None, of.get("k8s.sa.name") or ""
    try:
        p = core_v1.read_namespaced_pod(name=pod_name, namespace=namespace)
        pod_uid = p.metadata.uid
        sa_name = sa_name or (p.spec.service_account_name or "")
    except ApiException as e:
        rec["pod_lookup"] = f"{e.status} {e.reason}"
    rec["target_pod_uid"], rec["service_account"] = pod_uid, sa_name

    results = []
    for step in steps:
        if step == "quarantine":
            results.append(quarantine_pod_network(namespace, pod_name, pod_uid))
        elif step == "revoke_sa":
            results.append(revoke_service_account(namespace, sa_name))
        elif step == "terminate":
            results.append(terminate_pod(namespace, pod_name))
    rec["actions"] = results
    rec["t_actions_done"] = time.time()

    # Confirm the *final* state. Termination is the strongest guarantee, so
    # if the plan terminates, confirmation means the original pod is gone.
    if "terminate" in steps:
        t_conf = confirm_pod_absent(namespace, pod_name, pod_uid)
    else:
        pol = next((a.get("policy") for a in results if a["action"] == "quarantine"), None)
        t_conf = confirm_netpol_present(namespace, pol) if pol else None
    rec["t_confirmed"] = t_conf
    # NetworkPolicy *enforcement* depends on the CNI and is not observable
    # through the API; it must be verified separately by a connectivity probe.
    rec["network_enforcement_verified"] = False
    rec["success"] = bool(all(a["ok"] for a in results) and t_conf is not None)
    rec["mttc_seconds"] = None if t_conf is None else round(t_conf - rec["t_received"], 6)
    return rec


# ---------------------------------------------------------------------------
# Queue and workers (async mode)
# ---------------------------------------------------------------------------
event_queue: "Queue[dict]" = Queue(maxsize=QUEUE_MAXSIZE)
_dedup_cache: dict = {}
_dedup_lock = threading.Lock()


def _worker_loop():
    while True:
        try:
            event = event_queue.get(timeout=1.0)
        except Empty:
            continue
        try:
            write_audit(remediate(event))
        except Exception as e:  # keep the worker alive, but never lose the event
            logger.exception("worker failure")
            write_audit({"status": "worker_error", "error": repr(e), "success": False,
                         "falco_rule": event.get("rule"), "t_received": event.get("_t_received")})
        finally:
            event_queue.task_done()


def _start_workers():
    if KRE_MODE != "async":
        return
    for i in range(NUM_WORKERS):
        threading.Thread(target=_worker_loop, daemon=True, name=f"kre-worker-{i}").start()
    logger.info(f"KRE async mode: {NUM_WORKERS} workers, queue size {QUEUE_MAXSIZE}, {len(RULE_PLANS)} rule plans")


# ---------------------------------------------------------------------------
# HTTP API
# ---------------------------------------------------------------------------
app = Flask(__name__)


@app.route("/healthz", methods=["GET"])
@app.route("/health", methods=["GET"])
def healthz():
    return jsonify({"status": "ok", "mode": KRE_MODE, "queue_depth": event_queue.qsize()}), 200


@app.route("/remediate", methods=["POST"])
@app.route("/webhook", methods=["POST"])
@app.route("/events", methods=["POST"])
@app.route("/", methods=["POST"])
def ingest():
    t_received = time.time()
    payload = request.get_json(silent=True, force=True)
    if not isinstance(payload, dict):
        write_audit({"status": "rejected_invalid_json", "t_received": t_received, "success": False})
        return jsonify({"status": "rejected", "reason": "invalid_json"}), 400

    rule = payload.get("rule", "")
    of = payload.get("output_fields") or {}
    namespace = of.get("k8s.ns.name") or payload.get("namespace") or ""
    pod_name = of.get("k8s.pod.name") or payload.get("pod") or ""
    base = {"falco_rule": rule, "falco_time": payload.get("time"), "target_namespace": namespace,
            "target_pod": pod_name, "t_received": t_received, "success": False}

    if not pod_name or not namespace:
        write_audit({**base, "status": "ignored_missing_pod_metadata"})
        return jsonify({"status": "ignored", "reason": "missing pod or namespace"}), 200
    if not rule.startswith(RULE_PREFIX):
        write_audit({**base, "status": "ignored_non_msef_rule"})
        return jsonify({"status": "ignored", "reason": "rule not in MSEF set"}), 200
    if namespace not in TARGET_NAMESPACES:
        write_audit({**base, "status": "out_of_scope"})
        return jsonify({"status": "out_of_scope", "namespace": namespace}), 200

    token = hashlib.sha256(f"{rule}|{namespace}|{pod_name}".encode()).hexdigest()
    with _dedup_lock:
        last = _dedup_cache.get(token)
        if last is not None and (t_received - last) < DEBOUNCE_WINDOW_SEC:
            write_audit({**base, "status": "debounced"})
            return jsonify({"status": "debounced"}), 200
        _dedup_cache[token] = t_received
        cutoff = t_received - DEBOUNCE_WINDOW_SEC   # evict only expired entries
        for k in [k for k, v in _dedup_cache.items() if v < cutoff]:
            del _dedup_cache[k]

    payload["_t_received"] = t_received
    if KRE_MODE == "sync":
        rec = remediate(payload)
        write_audit(rec)
        return jsonify({"status": "contained" if rec["success"] else "failed", "record": rec}), 200

    try:
        event_queue.put_nowait(payload)
    except Full:
        write_audit({**base, "status": "dropped_queue_full"})
        return jsonify({"status": "dropped", "reason": "queue_full"}), 503
    return jsonify({"status": "accepted", "queue_depth": event_queue.qsize()}), 202


_start_workers()

if __name__ == "__main__":  # local development only; production uses gunicorn
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8080")), threaded=True)
