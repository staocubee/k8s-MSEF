#!/bin/bash
set -euo pipefail

FALCO_NS="${FALCO_NS:-falco}"
TARGET_NS="${TARGET_NS:-baseline}"
TARGET_POD="${TARGET_POD:-insecure-write-root}"
ATTACKER_POD="${ATTACKER_POD:-runtime-attacker}"
RESULTS_DIR="${RESULTS_DIR:-results}"

mkdir -p "$RESULTS_DIR"

SIMULATED=5
DETECTIONS=0

echo "===== Runtime Detection Rate Experiment ====="
echo "Start Time: $(date)"

FALCO_PODS=$(kubectl get pods -n "$FALCO_NS" -l app.kubernetes.io/name=falco -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null || true)

if [ -z "$FALCO_PODS" ]; then
  FALCO_PODS=$(kubectl get pods -n "$FALCO_NS" -l app=falco -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null || true)
fi

if [ -z "$FALCO_PODS" ]; then
  echo "ERROR: No Falco pods found in namespace $FALCO_NS"
  exit 1
fi

echo "Falco pods: $FALCO_PODS"
echo ""

run_attack() {
  local attack_name="$1"
  local pod_name="$2"
  local command="$3"
  local search_pattern="$4"

  echo "Running: $attack_name"

  kubectl exec -n "$TARGET_NS" "$pod_name" -- sh -c "$command" >/dev/null 2>&1 || true

  sleep 15

  local logs=""
  for falco_pod in $FALCO_PODS; do
    pod_logs=$(kubectl logs -n "$FALCO_NS" "$falco_pod" --since=60s 2>/dev/null || true)
    logs="${logs}
${pod_logs}"
  done

  if echo "$logs" | grep -Eiq "$pod_name|$search_pattern"; then
    DETECTIONS=$((DETECTIONS + 1))
    echo "Detected: YES"
  else
    echo "Detected: NO"
  fi

  echo "--------------------------------"
}

run_attack "Sensitive file access" "$TARGET_POD" "cat /etc/shadow" "shadow|sensitive|etc/shadow"
run_attack "Write to root filesystem" "$TARGET_POD" "touch /root/hacked" "write below root|root filesystem|/root/hacked"
run_attack "Privilege escalation attempt" "$TARGET_POD" "chmod +s /bin/sh" "setuid|chmod|privilege"
run_attack "Network via /dev/tcp" "$TARGET_POD" "echo test > /dev/tcp/example.com/80" "outbound|connection|example.com|network"
run_attack "Network via curl" "$ATTACKER_POD" "apk add --no-cache curl >/dev/null 2>&1 && curl -s http://example.com >/dev/null" "curl|outbound|connection|example.com|network"

RDR=$(echo "scale=2; $DETECTIONS / $SIMULATED" | bc)

echo ""
echo "===== Experiment Result ====="
echo "Simulated Attacks: $SIMULATED"
echo "Detected Attack Windows: $DETECTIONS"
echo "RDR = $RDR"
echo "End Time: $(date)"