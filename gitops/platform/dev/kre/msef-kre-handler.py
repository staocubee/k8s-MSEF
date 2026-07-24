import json
import os
import time

from flask import Flask, request, jsonify
from kubernetes import client, config

config.load_incluster_config()

v1 = client.CoreV1Api()

app = Flask(__name__)

# Updated path for evaluation metric persistence
METRICS_FILE = "/data/results/rrsr-events.jsonl"


def delete_pod(namespace, pod):
    v1.delete_namespaced_pod(
        pod,
        namespace,
        body=client.V1DeleteOptions(
            grace_period_seconds=0
        ),
    )


PLAYBOOKS = {
    # Default Falco Rule Names + Custom Aliases
    "Sensitive File Access": delete_pod,
    "Read sensitive file untrusted": delete_pod,
    "Write below root": delete_pod,
    "Terminal shell": delete_pod,
    "Terminal shell in container": delete_pod,
    "Outbound Connection": delete_pod,
    "Outbound Curl": delete_pod,
}


@app.route("/health")
def health():
    return {"status": "ok"}


@app.route("/remediate", methods=["POST"])
def remediate():
    payload = request.json
    rule = payload.get("rule", "")
    fields = payload.get("output_fields", {})

    namespace = fields.get("k8s.ns.name")
    pod = fields.get("k8s.pod.name")

    if not namespace or not pod:
        return jsonify({"status": "ignored"}), 400

    handler = PLAYBOOKS.get(rule)

    if handler is None:
        return jsonify({"status": "unsupported"}), 200

    start = time.time()
    success = False

    try:
        handler(namespace, pod)

        for _ in range(10):
            time.sleep(0.5)
            try:
                v1.read_namespaced_pod(pod, namespace)
            except client.exceptions.ApiException as e:
                if e.status == 404:
                    success = True
                    break

        latency = round(time.time() - start, 3)

        event = {
            "timestamp": time.time(),
            "rule": rule,
            "namespace": namespace,
            "pod": pod,
            "success": success,
            "latency": latency,
        }

        # Ensure directory path exists before writing log event
        os.makedirs(os.path.dirname(METRICS_FILE), exist_ok=True)

        with open(METRICS_FILE, "a") as f:
            f.write(json.dumps(event) + "\n")

        return jsonify(event)

    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=8080,
    )