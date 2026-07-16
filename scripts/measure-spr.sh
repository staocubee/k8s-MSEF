#!/usr/bin/env bash

###############################################################################
# measure-spr.sh
#
# Supply-Chain Policy Rejection Rate (SPR)
#
# SPR = Blocked Unsigned Images / Total Unsigned Images
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"
JSON_DIR="${RESULTS_DIR}/json"
TXT_DIR="${RESULTS_DIR}/txt"
LOG_DIR="${RESULTS_DIR}/logs"

mkdir -p "$JSON_DIR" "$TXT_DIR" "$LOG_DIR"

MANIFEST="${MANIFEST:-${ROOT_DIR}/k8s/integrity-tests/default-unsigned-image.yaml}"
TOTAL="${TOTAL:-10}"

BLOCKED=0
ALLOWED=0

LOG_FILE="${LOG_DIR}/spr-details.log"

> "$LOG_FILE"

echo "=========================================="
echo "Supply-Chain Policy Rejection Rate (SPR)"
echo "=========================================="
echo

for i in $(seq 1 "$TOTAL"); do

    TMP_FILE="/tmp/unsigned-test-$i.yaml"

    sed "s/name: unsigned-test/name: unsigned-test-$i/g" \
        "$MANIFEST" > "$TMP_FILE"

    OUTPUT=$(kubectl apply \
        --dry-run=server \
        -f "$TMP_FILE" 2>&1 || true)

    if echo "$OUTPUT" | grep -Eiq \
        "signature|cosign|attestor|verify|verified|denied|failed|no matching signatures"; then

        BLOCKED=$((BLOCKED+1))

        echo "Attempt $i : BLOCKED"

    else

        ALLOWED=$((ALLOWED+1))

        echo "Attempt $i : ALLOWED"

    fi

    {
        echo "Attempt $i"
        echo "$OUTPUT"
        echo "--------------------------------------"
    } >> "$LOG_FILE"

done

SPR=$(awk "BEGIN {printf \"%.2f\", $BLOCKED/$TOTAL}")

###############################################
# JSON
###############################################

cat > "$JSON_DIR/spr.json" <<EOF
{
  "metric":"SPR",
  "total":$TOTAL,
  "blocked":$BLOCKED,
  "allowed":$ALLOWED,
  "score":$SPR
}
EOF

###############################################
# TXT
###############################################

cat > "$TXT_DIR/spr.txt" <<EOF
==========================================
Supply-Chain Policy Rejection Rate (SPR)
==========================================

Total Unsigned Images

$TOTAL

Blocked

$BLOCKED

Allowed

$ALLOWED

SPR

$SPR

Generated

$(date)

EOF

###############################################

cat "$TXT_DIR/spr.txt"