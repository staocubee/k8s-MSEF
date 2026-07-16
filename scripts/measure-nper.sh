#!/bin/bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Metric:
# Network Policy Enforcement Rate (NPER)
#
# NPER = Correct Network Policy Decisions / Total Tests
#
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

###############################################################################

TEST_DIR="${TEST_DIR:-k8s/network-test}"

NAMESPACE="${NAMESPACE:-hardened}"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="${RESULTS_DIR}/json"

TXT_DIR="${RESULTS_DIR}/txt"

LOG_DIR="${RESULTS_DIR}/logs"

mkdir -p "$JSON_DIR" "$TXT_DIR" "$LOG_DIR"

DETAILS="$LOG_DIR/nper-details.log"

> "$DETAILS"

###############################################################################

echo "=========================================="

echo "Network Policy Enforcement Rate (NPER)"

echo "=========================================="

TOTAL=0

PASSED=0

FAILED=0

###############################################################################

for FILE in "$TEST_DIR"/*.yaml
do

    TOTAL=$((TOTAL+1))

    NAME=$(basename "$FILE")

    POD=$(basename "$FILE" .yaml)

    echo "Testing: $NAME"

    kubectl delete -f "$FILE" --ignore-not-found >/dev/null 2>&1 || true

    kubectl apply -f "$FILE" >/dev/null

    kubectl wait \
        --for=condition=Ready \
        pod/"$POD" \
        -n "$NAMESPACE" \
        --timeout=60s >/dev/null 2>&1 || true

    sleep 10

    LOGS=$(kubectl logs "$POD" -n "$NAMESPACE" 2>/dev/null || true)

    if [[ "$NAME" == *allowed* ]]; then

        if echo "$LOGS" | grep -qi success; then

            RESULT="ALLOWED"

            PASSED=$((PASSED+1))

        else

            RESULT="BLOCKED (Unexpected)"

            FAILED=$((FAILED+1))

        fi

    else

        if echo "$LOGS" | grep -Eiq "denied|timeout|connection refused"; then

            RESULT="BLOCKED"

            PASSED=$((PASSED+1))

        else

            RESULT="ALLOWED (Unexpected)"

            FAILED=$((FAILED+1))

        fi

    fi

cat >> "$DETAILS" <<EOF
Test: $NAME
Result: $RESULT
----------------------------------------
EOF

    kubectl delete pod "$POD" \
        -n "$NAMESPACE" \
        --ignore-not-found >/dev/null 2>&1 || true

done

###############################################################################

NPER=$(awk -v p="$PASSED" -v t="$TOTAL" 'BEGIN{printf "%.2f",p/t}')

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/nper.json" <<EOF
{
    "metric":"NPER",
    "total_tests":$TOTAL,
    "correct_decisions":$PASSED,
    "incorrect_decisions":$FAILED,
    "score":$NPER
}
EOF

###############################################################################
# TXT
###############################################################################

cat > "$TXT_DIR/nper.txt" <<EOF
==========================================
Network Policy Enforcement Rate
==========================================

Total Tests         : $TOTAL
Correct Decisions   : $PASSED
Incorrect Decisions : $FAILED

NPER                : $NPER

Generated : $(date)

EOF

cat "$JSON_DIR/nper.json"