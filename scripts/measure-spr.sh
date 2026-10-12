#!/usr/bin/env bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Metric:
# Supply-Chain Policy Rejection Rate (SPR)
#
# SPR = Blocked Unsigned Images / Total Unsigned Images
#
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/kubernetes.sh"

###############################################################################

TEST_MANIFEST="${TEST_MANIFEST:-$PROJECT_ROOT/k8s/integrity-tests/default-unsigned-image.yaml}"

TOTAL="${TOTAL:-10}"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="$RESULTS_DIR/json"
TXT_DIR="$RESULTS_DIR/txt"
LOG_DIR="$RESULTS_DIR/logs"

mkdir -p "$JSON_DIR" "$TXT_DIR" "$LOG_DIR"

LOG_FILE="$LOG_DIR/spr.log"

> "$LOG_FILE"

###############################################################################

echo "=========================================="
echo "Supply-Chain Policy Rejection Rate (SPR)"
echo "=========================================="

BLOCKED=0
ALLOWED=0

###############################################################################

for i in $(seq 1 "$TOTAL")
do

    TMP="/tmp/unsigned-image-$i.yaml"

    sed \
        "s/name: unsigned-test/name: unsigned-test-$i/" \
        "$TEST_MANIFEST" > "$TMP"

    OUTPUT=$(kubectl apply \
        --dry-run=server \
        -f "$TMP" \
        2>&1 || true)

    if echo "$OUTPUT" | grep -Eiq \
        "signature|cosign|verify|attestor|denied|failed|no matching signatures"
    then

        RESULT="BLOCKED"

        BLOCKED=$((BLOCKED+1))

    else

        RESULT="ALLOWED"

        ALLOWED=$((ALLOWED+1))

    fi

    cat >> "$LOG_FILE" <<EOF
Attempt : $i
Result  : $RESULT

$OUTPUT

----------------------------------------

EOF

done

###############################################################################

SPR=$(awk \
    -v b="$BLOCKED" \
    -v t="$TOTAL" \
    'BEGIN { printf "%.2f", b/t }')

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/spr.json" <<EOF
{
  "metric":"SPR",
  "total_tests":$TOTAL,
  "blocked":$BLOCKED,
  "allowed":$ALLOWED,
  "score":$SPR
}
EOF

###############################################################################
# TXT
###############################################################################

cat > "$TXT_DIR/spr.txt" <<EOF
==========================================
Supply-Chain Policy Rejection Rate (SPR)
==========================================

Total Tests : $TOTAL

Blocked     : $BLOCKED

Allowed     : $ALLOWED

SPR         : $SPR

Generated : $(date)

EOF

cat "$JSON_DIR/spr.json"