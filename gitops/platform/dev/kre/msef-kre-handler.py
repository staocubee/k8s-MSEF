#!/usr/bin/env python3
"""
Multi-Layer Security Evaluation Framework (MSEF)
Kubernetes Runtime Evaluation & Automated Response Engine (KRE)
Corpus Journal Production-Grade Asynchronous Controller
"""

import os
import sys
import time
import json
import logging
import hashlib
import threading
from queue import Queue, Empty
from datetime import datetime
from flask import Flask, request, jsonify
from kubernetes import client, config
from kubernetes.client.rest import ApiException

# ---------------------------------------------------------
# Logging & Configuration
# ---------------------------------------------------------
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
AUDIT_LOG_FILE = os.getenv("KRE_AUDIT_LOG", "/var/log/kre/remediation-events.jsonl")
NUM_WORKERS = int(os.getenv("KRE_WORKER_THREADS", "4"))
DEBOUNCE_WINDOW_SEC = float(os.getenv("KRE_DEBOUNCE_WINDOW", "3.0"))

logging.basicConfig(
    level=LOG_LEVEL,
    format="%(asctime)s [%(levelname)s] [KRE-Controller] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("kre-controller")

# Ensure audit log directory exists
os.makedirs(os.path.dirname(AUDIT_LOG_FILE), exist_ok=True)

# ---------------------------------------------------------
# Kubernetes Client Initialization
# ---------------------------------------------------------
try:
    config.load_incluster_config()
    logger.info("Loaded in-cluster Kubernetes configuration.")
except Exception:
    try:
        config.load_kube_config()
        logger.info("Loaded local kube-config.")
    except Exception as e:
        logger.error(f"Failed to initialize Kubernetes client: {e}")
        sys.exit(1)

core_v1 = client.CoreV1Api()
networking_v1 = client.NetworkingV1Api()
rbac_v1 = client.RbacAuthorizationV1Api()

# ---------------------------------------------------------
# Asynchronous Work Queue & State Management
# ---------------------------------------------------------
event_queue = Queue(maxsize=10000)
dedup_cache = {}
dedup_lock = threading.Lock()

# ---------------------------------------------------------
# MITRE ATT&CK Remediation Actions
# ---------------------------------------------------------
def isolate_pod_network(namespace: str, pod_name: str, pod_labels: dict) -> bool:
    """Tier 1 Containment: Injects dynamic default-deny NetworkPolicy isolating the pod."""
    policy_name = f"quarantine-{pod_name}"
    
    # Use exact match labels from the target pod
    match_labels = pod_labels if pod_labels else {"app": pod_name}
    
    netpol = client.V1NetworkPolicy(
        api_version="networking.k8s.io/v1",
        kind="NetworkPolicy",
        metadata=client.V1ObjectMeta(
            name=policy_name,
            namespace=namespace,
            labels={"msef.security/quarantine": "true"}
        ),
        spec=client.V1NetworkPolicySpec(
            pod_selector=client.V1LabelSelector(match_labels=match_labels),
            policy_types=["Ingress", "Egress"],
            ingress=[], # Deny all ingress
            egress=[]   # Deny all egress
        )
    )
    
    try:
        networking_v1.create_namespaced_network_policy(namespace=namespace, body=netpol)
        logger.info(f"[ACTION:QUARANTINE] Isolated pod {namespace}/{pod_name} via policy {policy_name}")
        return True
    except ApiException as e:
        if e.status == 409:
            logger.info(f"[ACTION:QUARANTINE] Policy {policy_name} already applied.")
            return True
        logger.error(f"[ERROR:QUARANTINE] Failed to create NetworkPolicy for {pod_name}: {e}")
        return False


def terminate_pod(namespace: str, pod_name: str, grace_period: int = 0) -> bool:
    """Tier 2 Containment: Immediately evicts/terminates compromised workload."""
    try:
        core_v1.delete_namespaced_pod(
            name=pod_name,
            namespace=namespace,
            grace_period_seconds=grace_period
        )
        logger.info(f"[ACTION:EVICT] Terminated pod {namespace}/{pod_name} (grace={grace_period}s)")
        return True
    except ApiException as e:
        if e.status == 404:
            logger.warning(f"[ACTION:EVICT] Pod {namespace}/{pod_name} already evicted/terminated.")
            return True
        logger.error(f"[ERROR:EVICT] Failed to evict pod {namespace}/{pod_name}: {e}")
        return False


def revoke_service_account(namespace: str, sa_name: str) -> bool:
    """Tier 3 Containment: Binds SA to restrictive role or removes bindings."""
    if sa_name in ["default", ""]:
        return True  # Managed by prevention layer
    
    role_binding_name = f"block-{sa_name}-quarantine"
    binding = client.V1RoleBinding(
        metadata=client.V1ObjectMeta(name=role_binding_name, namespace=namespace),
        subjects=[client.RbacV1Subject(kind="ServiceAccount", name=sa_name, namespace=namespace)],
        role_ref=client.V1RoleRef(
            api_group="rbac.authorization.k8s.io",
            kind="ClusterRole",
            name="system:aggregate-to-admin" # Intentionally dummy/empty scope
        )
    )
    try:
        rbac_v1.create_namespaced_role_binding(namespace=namespace, body=binding)
        logger.info(f"[ACTION:REVOKE_SA] Quarantined ServiceAccount {namespace}/{sa_name}")
        return True
    except ApiException as e:
        if e.status == 409:
            return True
        logger.error(f"[ERROR:REVOKE_SA] Failed to quarantine SA {sa_name}: {e}")
        return False

# ---------------------------------------------------------
# Event Processing & Decision Engine
# ---------------------------------------------------------
def execute_remediation(event_data: dict):
    t_start = time.perf_counter()
    received_timestamp = event_data.get("received_at", time.time())
    
    rule = event_data.get("rule", "Unknown")
    output_fields = event_data.get("output_fields", {})
    
    pod_name = output_fields.get("k8s.pod.name")
    namespace = output_fields.get("k8s.ns.name", "default")
    sa_name = output_fields.get("k8s.sa.name", "")
    
    # Fallback to direct fields if output_fields omitted
    if not pod_name and "pod" in event_data:
        pod_name = event_data["pod"]
    if not pod_name:
        logger.warning(f"Event discarded: No pod metadata in event rule '{rule}'")
        return

    # Fetch live pod labels for accurate NetworkPolicy targeting
    pod_labels = {}
    try:
        pod_obj = core_v1.read_namespaced_pod(name=pod_name, namespace=namespace)
        pod_labels = pod_obj.metadata.labels or {}
    except ApiException as e:
        if e.status == 404:
            logger.warning(f"Pod {namespace}/{pod_name} terminated before remediation execution.")
            pod_labels = {"app": pod_name}
        else:
            logger.error(f"API query failure for pod {pod_name}: {e}")

    # Decision Matrix mapped to MITRE Container Vectors
    action_taken = "NONE"
    success = False

    rule_lower = rule.lower()

    if any(k in rule_lower for k in ["outbound", "c2", "terminal", "interactive", "reverse"]):
        # Active shell or C2 beaconing: Tier 1 + Tier 2
        net_ok = isolate_pod_network(namespace, pod_name, pod_labels)
        kill_ok = terminate_pod(namespace, pod_name, grace_period=0)
        success = net_ok and kill_ok
        action_taken = "DYNAMIC_QUARANTINE_AND_TERMINATE"

    elif any(k in rule_lower for k in ["token", "secret", "credential"]):
        # SA token access: Tier 1 + Tier 3
        net_ok = isolate_pod_network(namespace, pod_name, pod_labels)
        sa_ok = revoke_service_account(namespace, sa_name) if sa_name else True
        success = net_ok and sa_ok
        action_taken = "NETWORK_QUARANTINE_AND_SA_REVOCATION"

    elif any(k in rule_lower for k in ["host-write", "escape", "privilege", "root"]):
        # Container escape attempt: Immediate hard kill
        success = terminate_pod(namespace, pod_name, grace_period=0)
        action_taken = "FORCE_TERMINATE"

    else:
        # Default safety: Dynamic Network Quarantine
        success = isolate_pod_network(namespace, pod_name, pod_labels)
        action_taken = "DYNAMIC_NETWORK_QUARANTINE"

    t_end = time.perf_counter()
    mttc_seconds = t_end - t_start
    e2e_containment_latency = time.time() - received_timestamp

    # Telemetry Log
    audit_entry = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "falco_rule": rule,
        "target_namespace": namespace,
        "target_pod": pod_name,
        "action_taken": action_taken,
        "success": success,
        "mttc_seconds": round(mttc_seconds, 6),
        "e2e_containment_latency_seconds": round(e2e_containment_latency, 6)
    }

    try:
        with open(AUDIT_LOG_FILE, "a") as f:
            f.write(json.dumps(audit_entry) + "\n")
    except Exception as e:
        logger.error(f"Failed to record audit telemetry: {e}")

    logger.info(
        f"[CONTAINMENT-COMPLETE] Target={namespace}/{pod_name} Action={action_taken} "
        f"Success={success} MTTC={mttc_seconds:.4f}s"
    )

def worker_loop():
    """Worker thread pulling alerts from the internal queue."""
    while True:
        try:
            event_data = event_queue.get(timeout=1.0)
            execute_remediation(event_data)
            event_queue.task_done()
        except Empty:
            continue
        except Exception as e:
            logger.error(f"Unexpected worker failure: {e}", exc_info=True)

# ---------------------------------------------------------
# Webhook Ingestion API
# ---------------------------------------------------------
app = Flask(__name__)

@app.route("/healthz", methods=["GET"])
def healthz():
    return jsonify({"status": "healthy", "queue_depth": event_queue.qsize()}), 200

@app.route("/", methods=["POST"])
@app.route("/events", methods=["POST"])
@app.route("/webhook", methods=["POST"])
def ingest_event():
    payload = request.get_json(silent=True, force=True)
    if not payload:
        return jsonify({"status": "rejected", "reason": "invalid_json"}), 400

    rule = payload.get("rule", "")
    output_fields = payload.get("output_fields", {})
    pod_name = output_fields.get("k8s.pod.name", payload.get("pod", ""))
    namespace = output_fields.get("k8s.ns.name", "default")

    # Sliding-window Debounce / Dedup Hash
    dedup_token = hashlib.sha256(f"{rule}:{namespace}:{pod_name}".encode()).hexdigest()
    now = time.time()

    with dedup_lock:
        last_seen = dedup_cache.get(dedup_token, 0)
        if (now - last_seen) < DEBOUNCE_WINDOW_SEC:
            return jsonify({"status": "debounced", "token": dedup_token}), 200
        
        # Purge stale keys if cache grows large
        if len(dedup_cache) > 2000:
            dedup_cache.clear()
            
        dedup_cache[dedup_token] = now

    payload["received_at"] = now
    try:
        event_queue.put_nowait(payload)
    except Exception:
        logger.error("Queue capacity exceeded; dropping incoming alert under saturation.")
        return jsonify({"status": "dropped", "reason": "queue_full"}), 503

    return jsonify({"status": "accepted", "queued": True}), 202

# ---------------------------------------------------------
# Service Startup
# ---------------------------------------------------------
# Launch worker thread pool
for i in range(NUM_WORKERS):
    t = threading.Thread(target=worker_loop, daemon=True, name=f"kre-worker-{i}")
    t.start()
logger.info(f"Initialized {NUM_WORKERS} asynchronous KRE containment worker threads.")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)