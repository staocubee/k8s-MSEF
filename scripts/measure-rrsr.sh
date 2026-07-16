#!/bin/bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Metric:
# Runtime Response Success Rate (RRSR)
#
# RRSR = Successful Responses / Runtime Attacks
#
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

###############################################################################

TEST_DIR="${TEST_DIR:-k8s/response-tests}"

NAMESPACE="${NAMESPACE:-hardened}"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="${RESULTS_DIR}/json"

TXT_DIR="${RESULTS_DIR}/txt"

LOG_DIR="${RESULTS_DIR}/logs"

mkdir -p "$JSON_DIR" "$TXT_DIR" "$LOG_DIR"

DETAILS="$LOG_DIR/rrsr-details.log"

> "$DETAILS"

###############################################################################

echo "=========================================="

echo "Runtime Response Success Rate (RRSR)"

echo "=========================================="

###############################################################################

TOTAL=0

SUCCESS=0

FAILED=0

###############################################################################

for FILE in "$TEST_DIR"/*.yaml
do

TOTAL=$((TOTAL+1))

POD=$(basename "$FILE" .yaml)

echo "Testing Response: $POD"

kubectl delete -f "$FILE" --ignore-not-found >/dev/null 2>&1

kubectl apply -f "$FILE" >/dev/null

sleep 40

STATUS=$(kubectl get pod "$POD" \
-n "$NAMESPACE" \
--ignore-not-found \
-o jsonpath='{.status.phase}' 2>/dev/null)

if [ -z "$STATUS" ]
then

SUCCESS=$((SUCCESS+1))

RESULT="SUCCESS"

else

FAILED=$((FAILED+1))

RESULT="FAILED"

fi

cat >> "$DETAILS" <<EOF
Pod: $POD
Result: $RESULT
----------------------------------------
EOF

done

###############################################################################

RRSR=$(awk -v s="$SUCCESS" -v t="$TOTAL" 'BEGIN{printf "%.2f",s/t}')

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/rrsr.json" <<EOF
{
    "metric":"RRSR",
    "runtime_attacks":$TOTAL,
    "successful_responses":$SUCCESS,
    "failed_responses":$FAILED,
    "score":$RRSR
}
EOF

###############################################################################
# TXT
###############################################################################

cat > "$TXT_DIR/rrsr.txt" <<EOF
==========================================
Runtime Response Success Rate
==========================================

Runtime Attacks      : $TOTAL
Successful Responses : $SUCCESS
Failed Responses     : $FAILED

RRSR                 : $RRSR

Generated : $(date)

EOF

cat "$JSON_DIR/rrsr.json"