#!/bin/bash
set -euo pipefail

FALCO_NS="${FALCO_NS:-falco}"
TARGET_NS="${TARGET_NS:-baseline}"
TARGET_POD="${TARGET_POD:-insecure-write-root}"
ATTACKER_POD="${ATTACKER_POD:-runtime-attacker}"
RESULTS_DIR="${RESULTS_DIR:-results}"

mkdir -p "$RESULTS_DIR"

echo "===== Mean Time To Detect Experiment ====="
echo "Start Time: $(date)"

# Check required commands
for cmd in kubectl date awk grep bc; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: Required command '$cmd' not found."
    exit 1
  fi
done

# Check pods exist
if ! kubectl get pod "$TARGET_POD" -n "$TARGET_NS" >/dev/null 2>&1; then
  echo "ERROR: Target pod '$TARGET_POD' not found in namespace '$TARGET_NS'."
  exit 1
fi

if ! kubectl get pod "$ATTACKER_POD" -n "$TARGET_NS" >/dev/null 2>&1; then
  echo "ERROR: Attacker pod '$ATTACKER_POD' not found in namespace '$TARGET_NS'."
  exit 1
fi

# Check Falco exists
FALCO_PODS=$(kubectl get pods -n "$FALCO_NS" -l app.kubernetes.io/name=falco -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null || true)

if [ -z "$FALCO_PODS" ]; then
  # fallback for some Falco Helm labels
  FALCO_PODS=$(kubectl get pods -n "$FALCO_NS" -l app=falco -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null || true)
fi

if [ -z "$FALCO_PODS" ]; then
  echo "ERROR: No Falco pods found in namespace '$FALCO_NS'."
  exit 1
fi

echo "Falco pods: $FALCO_PODS"
echo ""

TOTAL_DETECTION_TIME=0
DETECTED_ATTACKS=0
SIMULATED_ATTACKS=5

run_attack_and_measure() {
  local attack_name="$1"
  local pod_name="$2"
  local command="$3"

  echo "Running attack: $attack_name"

  local start_epoch
  start_epoch=$(date +%s)

  # Execute attack command; do not fail script if attack command fails
  kubectl exec -n "$TARGET_NS" "$pod_name" -- sh -c "$command" >/dev/null 2>&1 || true

  # Give Falco time to process
  sleep 8

  local logs=""
  for falco_pod in $FALCO_PODS; do
    pod_logs=$(kubectl logs -n "$FALCO_NS" "$falco_pod" --since=30s 2>/dev/null || true)
    logs="${logs}
${pod_logs}"
  done

  # Try to find the pod name in Falco logs
  local detected_line
  detected_line=$(echo "$logs" | grep -i "$pod_name" | head -n 1 || true)

  if [ -n "$detected_line" ]; then
    local end_epoch
    end_epoch=$(date +%s)

    local detection_time
    detection_time=$((end_epoch - start_epoch))

    TOTAL_DETECTION_TIME=$((TOTAL_DETECTION_TIME + detection_time))
    DETECTED_ATTACKS=$((DETECTED_ATTACKS + 1))

    echo "Detected: YES"
    echo "Detection Time: ${detection_time}s"
  else
    echo "Detected: NO"
    echo "Detection Time: N/A"
  fi

  echo "--------------------------------"
}

run_attack_and_measure "Sensitive file access" "$TARGET_POD" "cat /etc/shadow"
run_attack_and_measure "Root filesystem modification" "$TARGET_POD" "touch /root/mttd-test"
run_attack_and_measure "Privilege escalation attempt" "$TARGET_POD" "chmod +s /bin/sh"
run_attack_and_measure "Network via /dev/tcp" "$TARGET_POD" "echo test > /dev/tcp/example.com/80"
run_attack_and_measure "Network via curl" "$ATTACKER_POD" "apk add --no-cache curl >/dev/null 2>&1 && curl -s http://example.com >/dev/null"

if [ "$DETECTED_ATTACKS" -gt 0 ]; then
  MTTD=$(echo "scale=2; $TOTAL_DETECTION_TIME / $DETECTED_ATTACKS" | bc)
else
  MTTD="0"
fi

echo ""
echo "===== Experiment Result ====="
echo "Simulated Attacks: $SIMULATED_ATTACKS"
echo "Detected Attacks: $DETECTED_ATTACKS"
echo "Total Detection Time: ${TOTAL_DETECTION_TIME}s"
echo "MTTD = ${MTTD}s"
echo "End Time: $(date)"

cat > "$RESULTS_DIR/mttd-result.txt" <<EOF
Simulated Attacks: $SIMULATED_ATTACKS
Detected Attacks: $DETECTED_ATTACKS
Total Detection Time: ${TOTAL_DETECTION_TIME}s
MTTD = ${MTTD}s
Timestamp: $(date)
EOF