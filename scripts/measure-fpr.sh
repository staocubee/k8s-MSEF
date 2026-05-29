#!/bin/bash
set -euo pipefail

FALCO_NS="${FALCO_NS:-falco}"
TARGET_NS="${TARGET_NS:-baseline}"
WINDOWS="${WINDOWS:-5}"
RESULTS_DIR="${RESULTS_DIR:-results}"

mkdir -p "$RESULTS_DIR"

FALSE_ALERT_WINDOWS=0

echo "===== False Positive Rate Experiment ====="
echo "Benign Workload Windows: $WINDOWS"
echo ""

for i in $(seq 1 "$WINDOWS"); do
  POD_NAME="benign-workload-$i"

  echo "Running benign workload window $i"

  kubectl run "$POD_NAME" \
    --image=alpine:latest \
    -n "$TARGET_NS" \
    --restart=Never \
    -- sh -c "echo benign-test && ls /tmp && sleep 5" >/dev/null 2>&1 || true

  sleep 10

  LOGS=$(kubectl logs -n "$FALCO_NS" -l app.kubernetes.io/name=falco --since=20s 2>/dev/null || true)

  if [ -z "$LOGS" ]; then
    LOGS=$(kubectl logs -n "$FALCO_NS" -l app=falco --since=20s 2>/dev/null || true)
  fi

  if echo "$LOGS" | grep -qi "$POD_NAME"; then
    FALSE_ALERT_WINDOWS=$((FALSE_ALERT_WINDOWS + 1))
    echo "False Alert: YES"
  else
    echo "False Alert: NO"
  fi

  kubectl delete pod "$POD_NAME" -n "$TARGET_NS" --ignore-not-found >/dev/null 2>&1 || true
  echo "--------------------------------"
done

FPR=$(echo "scale=2; $FALSE_ALERT_WINDOWS / $WINDOWS" | bc)

echo ""
echo "===== Experiment Result ====="
echo "Benign Windows: $WINDOWS"
echo "False Alert Windows: $FALSE_ALERT_WINDOWS"
echo "FPR = $FPR"
echo "Timestamp: $(date)"