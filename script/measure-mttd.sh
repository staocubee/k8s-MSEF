#!/bin/bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Metric:
# Mean Time To Detect (MTTD)
#
# MTTD = Average Detection Time (seconds)
#
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

###############################################################################
# Configuration
###############################################################################

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="${RESULTS_DIR}/json"

TXT_DIR="${RESULTS_DIR}/txt"

mkdir -p "$JSON_DIR" "$TXT_DIR"

VALUES_FILE="${RESULTS_DIR}/mttd-values.txt"

###############################################################################

echo "=========================================="

echo "Mean Time To Detect (MTTD)"

echo "=========================================="

###############################################################################

if [ ! -f "$VALUES_FILE" ]; then

    echo "ERROR: $VALUES_FILE not found."

    echo "Run measure-rdr.sh first."

    exit 1

fi

COUNT=$(wc -l < "$VALUES_FILE")

SUM=$(awk '{s+=$1} END{print s}' "$VALUES_FILE")

MEAN=$(awk -v s="$SUM" -v c="$COUNT" 'BEGIN{printf "%.2f",s/c}')

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/mttd.json" <<EOF
{
    "metric":"MTTD",
    "detections":$COUNT,
    "total_time_seconds":$SUM,
    "score":$MEAN,
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

Total Time       : $SUM seconds

MTTD             : $MEAN seconds

Generated : $(date)

EOF

cat "$JSON_DIR/mttd.json"