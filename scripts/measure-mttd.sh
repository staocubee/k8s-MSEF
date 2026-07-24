#!/usr/bin/env bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Mean Time To Detect (MTTD)
#
# MTTD = Average Detection Time for Detected Runtime Attacks
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"

###############################################################################

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="$RESULTS_DIR/json"
TXT_DIR="$RESULTS_DIR/txt"

mkdir -p \
    "$JSON_DIR" \
    "$TXT_DIR"

RDR_JSON="$JSON_DIR/rdr.json"

###############################################################################

echo "=========================================="
echo "Mean Time To Detect (MTTD)"
echo "=========================================="

[[ -f "$RDR_JSON" ]] || fail "Run measure-rdr.sh first."

###############################################################################
# Extract detected attack times
###############################################################################

COUNT=$(jq '[.attacks[] | select(.detected==true)] | length' "$RDR_JSON")

if [[ "$COUNT" -eq 0 ]]; then

    TOTAL_TIME=0
    MTTD=0

else

    TOTAL_TIME=$(
        jq '[.attacks[]
            | select(.detected==true)
            | .time_seconds]
            | add' "$RDR_JSON"
    )

    MTTD=$(awk \
        -v s="$TOTAL_TIME" \
        -v c="$COUNT" \
        'BEGIN{printf "%.2f",s/c}')

fi

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/mttd.json" <<EOF
{
  "metric":"MTTD",
  "detections":$COUNT,
  "total_time_seconds":$TOTAL_TIME,
  "score":$MTTD,
  "unit":"seconds"
}
EOF

###############################################################################
# TXT
###############################################################################

cat > "$TXT_DIR/mttd.txt" <<EOF
==========================================
Mean Time To Detect
==========================================

Detection Events : $COUNT
Total Time       : $TOTAL_TIME seconds

MTTD             : $MTTD seconds

Generated : $(date)

EOF

cat "$TXT_DIR/mttd.txt"