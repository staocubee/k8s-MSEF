#!/bin/bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Metric:
# False Positive Rate (FPR)
#
# FPR = False Alert Windows / Total Benign Windows
#
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

###############################################################################

FALCO_NS="${FALCO_NS:-falco}"
TARGET_NS="${TARGET_NS:-baseline}"
WINDOWS="${WINDOWS:-5}"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="${RESULTS_DIR}/json"
TXT_DIR="${RESULTS_DIR}/txt"
LOG_DIR="${RESULTS_DIR}/logs"

mkdir -p "$JSON_DIR" "$TXT_DIR" "$LOG_DIR"

DETAILS="$LOG_DIR/fpr-details.log"
> "$DETAILS"

###############################################################################

echo "=========================================="
echo "False Positive Rate (FPR)"
echo "=========================================="

FALSE_ALERTS=0

###############################################################################

FALCO_PODS=$(kubectl get pods -n "$FALCO_NS" \
-l app.kubernetes.io/name=falco \
-o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null || true)

if [ -z "$FALCO_PODS" ]; then
    FALCO_PODS=$(kubectl get pods -n "$FALCO_NS" \
    -l app=falco \
    -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null || true)
fi

###############################################################################

for i in $(seq 1 "$WINDOWS")
do

    POD="benign-workload-$i"

    echo "Running benign workload $i"

    kubectl run "$POD" \
        --image=alpine:latest \
        -n "$TARGET_NS" \
        --restart=Never \
        -- sh -c "echo healthy && sleep 5" >/dev/null 2>&1 || true

    sleep 12

    LOGS=""

    for FPOD in $FALCO_PODS
    do
        LOGS="${LOGS}
$(kubectl logs -n "$FALCO_NS" "$FPOD" --since=30s 2>/dev/null || true)"
    done

    if echo "$LOGS" | grep -qi "$POD"; then

        RESULT="FALSE ALERT"

        FALSE_ALERTS=$((FALSE_ALERTS+1))

    else

        RESULT="NO ALERT"

    fi

cat >> "$DETAILS" <<EOF
Window : $i
Pod    : $POD
Result : $RESULT
----------------------------------------
EOF

    kubectl delete pod "$POD" \
        -n "$TARGET_NS" \
        --ignore-not-found >/dev/null 2>&1 || true

done

###############################################################################

FPR=$(awk -v f="$FALSE_ALERTS" -v t="$WINDOWS" \
'BEGIN{printf "%.2f",f/t}')

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/fpr.json" <<EOF
{
  "metric":"FPR",
  "benign_windows":$WINDOWS,
  "false_alerts":$FALSE_ALERTS,
  "score":$FPR
}
EOF

###############################################################################
# TXT
###############################################################################

cat > "$TXT_DIR/fpr.txt" <<EOF
==========================================
False Positive Rate (FPR)
==========================================

Benign Windows : $WINDOWS
False Alerts   : $FALSE_ALERTS

FPR            : $FPR

Generated : $(date)

EOF

cat "$TXT_DIR/fpr.txt"