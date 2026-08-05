import json
import os
import time

from flask import Flask, jsonify, request
from kubernetes import client, config

# Initialize Kubernetes In-Cluster Config
try:
    config.load_incluster_config()
except config.ConfigException:
    config.load_kube_config()

v1 = client.CoreV1Api()

app = Flask(__name__)

# File path for storing response rate and latency evaluation metrics (RRSR)
METRICS_FILE = "/data/results/rrsr-events.jsonl"


def ensure_metrics_file():
    """Ensure the target directory and metrics file exist on startup."""
    try:
        os.makedirs(os.path.dirname(METRICS_FILE), exist_ok=True)
        if not os.path.exists(METRICS_FILE):
            open(METRICS_FILE, "a").close()
    except Exception as e:
        app.logger.error(f"Failed to initialize metrics file: {e}")


# Initialize storage path immediately
ensure_metrics_file()


def delete_pod(namespace, pod):
    """Executes immediate graceful pod deletion (grace_period_seconds=0)."""
    v1.delete_namespaced_pod(
        name=pod,
        namespace=namespace,
        body=client.V1DeleteOptions(grace_period_seconds=0),
    )


PLAYBOOKS = {
    # --------------------------------------------------------------------------
    # Custom MSEF Rules (runtime-test.yaml / response-test.yaml)
    # --------------------------------------------------------------------------
    "MSEF Outbound C2 Traffic": delete_pod,
    "MSEF Cloud Metadata Server Access": delete_pod,
    "MSEF Token and Sensitive File Access": delete_pod,
    "MSEF Interactive Shell Execution": delete_pod,
    "MSEF Host Filesystem Write Attempt": delete_pod,
    # --------------------------------------------------------------------------
    # Default Falco Rules & Legacy Aliases (Fallback)
    # --------------------------------------------------------------------------
    "Outbound Connection": delete_pod,
    "Outbound Curl": delete_pod,
    "Sensitive File Access": delete_pod,
    "Read sensitive file untrusted": delete_pod,
    "Terminal shell": delete_pod,
    "Terminal shell in container": delete_pod,
    "Write below root": delete_pod,
}


def log_rrsr_event(rule, namespace, pod, success, latency):
    """Writes JSONL metric records for the evaluation framework."""
    event = {
        "timestamp": time.time(),
        "rule": rule,
        "namespace": namespace,
        "pod": pod,
        "success": success,
        "latency": round(latency, 3),
    }
    try:
        os.makedirs(os.path.dirname(METRICS_FILE), exist_ok=True)
        with open(METRICS_FILE, "a") as f:
            f.write(json.dumps(event) + "\n")
    except Exception as e:
        app.logger.error(f"Failed to write metric log: {e}")
    return event


@app.route("/health")
def health():
    return {"status": "ok"}


@app.route("/remediate", methods=["POST"])
@app.route("/webhook", methods=["POST"])
def remediate():
    payload = request.json or {}
    rule = payload.get("rule", "")
    fields = payload.get("output_fields", {})

    namespace = fields.get("k8s.ns.name")
    pod = fields.get("k8s.pod.name")

    if not namespace or not pod:
        return (
            jsonify(
                {"status": "ignored", "reason": "missing namespace or pod field"}
            ),
            400,
        )

    handler = PLAYBOOKS.get(rule)

    if handler is None:
        return jsonify({"status": "unsupported", "rule": rule}), 200

    start = time.time()
    success = False

    try:
        # Issue Pod Deletion Call
        handler(namespace, pod)

        # Poll Kubernetes API to verify pod deletion (404 status code)
        for _ in range(10):
            time.sleep(0.5)
            try:
                v1.read_namespaced_pod(name=pod, namespace=namespace)
            except client.exceptions.ApiException as e:
                if e.status == 404:
                    success = True
                    break

        latency = time.time() - start
        event = log_rrsr_event(rule, namespace, pod, success, latency)
        return jsonify(event), 200

    except client.exceptions.ApiException as e:
        latency = time.time() - start
        # If the pod was already deleted before KRE could issue the call
        if e.status == 404:
            success = True
            event = log_rrsr_event(rule, namespace, pod, success, latency)
            return jsonify({"status": "already_deleted", "pod": pod}), 200

        # Log failed remediation due to API/RBAC errors
        log_rrsr_event(rule, namespace, pod, False, latency)
        return jsonify({"error": str(e)}), 500

    except Exception as e:
        latency = time.time() - start
        log_rrsr_event(rule, namespace, pod, False, latency)
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=8080,
    )