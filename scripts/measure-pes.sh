#!/usr/bin/env bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Metric:
# Prevention Effectiveness Score (PES)
#
# PES = (MBR + NPER + SMER) / 3
#
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"
JSON_DIR="$RESULTS_DIR/json"
TXT_DIR="$RESULTS_DIR/txt"

mkdir -p "$JSON_DIR" "$TXT_DIR"

###############################################################################
# Verify required metric files exist
###############################################################################

for file in mbr.json nper.json smer.json
do
    if [[ ! -f "$JSON_DIR/$file" ]]; then
        echo "Missing required file:"
        echo "  $JSON_DIR/$file"
        exit 1
    fi
done

###############################################################################
# Load metric values
###############################################################################

MBR=$(jq -r '.score' "$JSON_DIR/mbr.json")
NPER=$(jq -r '.score' "$JSON_DIR/nper.json")
SMER=$(jq -r '.score' "$JSON_DIR/smer.json")

###############################################################################
# Calculate PES
###############################################################################

PES=$(awk \
    -v a="$MBR" \
    -v b="$NPER" \
    -v c="$SMER" \
    'BEGIN { printf "%.2f", (a+b+c)/3 }')

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/pes.json" <<EOF
{
  "metric":"PES",
  "mbr":$MBR,
  "nper":$NPER,
  "smer":$SMER,
  "score":$PES
}
EOF

###############################################################################
# TXT
###############################################################################

cat > "$TXT_DIR/pes.txt" <<EOF
==========================================
Prevention Effectiveness Score (PES)
==========================================

Manifest Blocking Rate        : $MBR
Network Policy Enforcement    : $NPER
Secrets Management            : $SMER

------------------------------------------

PES                           : $PES

Generated: $(date)

EOF

cat "$JSON_DIR/pes.json"