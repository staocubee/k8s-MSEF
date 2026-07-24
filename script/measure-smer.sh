#!/bin/bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Metric:
# Secrets Management Enforcement Rate (SMER)
#
# SMER = Correct Secret Enforcement Decisions / Total Secret Tests
#
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

###############################################################################
# Configuration
###############################################################################

TEST_DIR="${TEST_DIR:-k8s/secrets-test}"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="${RESULTS_DIR}/json"

TXT_DIR="${RESULTS_DIR}/txt"

LOG_DIR="${RESULTS_DIR}/logs"

mkdir -p "$JSON_DIR" "$TXT_DIR" "$LOG_DIR"

DETAILS="$LOG_DIR/smer-details.log"

> "$DETAILS"

###############################################################################

echo "=========================================="

echo "Secrets Management Enforcement Rate (SMER)"

echo "=========================================="

TOTAL=0

PASSED=0

FAILED=0

###############################################################################

for FILE in "$TEST_DIR"/*.yaml
do

    TOTAL=$((TOTAL+1))

    NAME=$(basename "$FILE")

    echo "Testing: $NAME"

    kubectl delete -f "$FILE" --ignore-not-found >/dev/null 2>&1 || true

    OUTPUT=$(kubectl apply --dry-run=server -f "$FILE" 2>&1 || true)

    if [[ "$NAME" == *valid-external-secret* ]]; then

        if ! echo "$OUTPUT" | grep -qi denied; then

            RESULT="ALLOWED"

            PASSED=$((PASSED+1))

        else

            RESULT="BLOCKED (Unexpected)"

            FAILED=$((FAILED+1))

        fi

    else

        if echo "$OUTPUT" | grep -qi denied; then

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

done

###############################################################################

SMER=$(awk -v p="$PASSED" -v t="$TOTAL" 'BEGIN{printf "%.2f",p/t}')

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/smer.json" <<EOF
{
    "metric":"SMER",
    "total_tests":$TOTAL,
    "correct_decisions":$PASSED,
    "incorrect_decisions":$FAILED,
    "score":$SMER
}
EOF

###############################################################################
# TXT
###############################################################################

cat > "$TXT_DIR/smer.txt" <<EOF
==========================================
Secrets Management Enforcement Rate
==========================================

Total Tests         : $TOTAL
Correct Decisions   : $PASSED
Incorrect Decisions : $FAILED

SMER                : $SMER

Generated : $(date)

EOF

cat "$JSON_DIR/smer.json"