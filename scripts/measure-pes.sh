#!/usr/bin/env bash

#############################################################
# Prevention Effectiveness Score (PES)
#############################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"
JSON_DIR="${RESULTS_DIR}/json"
TXT_DIR="${RESULTS_DIR}/txt"

mkdir -p "$JSON_DIR" "$TXT_DIR"

MBR=$(jq '.trivy.score' "$JSON_DIR/mbr.json")
NPER=$(jq '.score' "$JSON_DIR/nper.json")
SMER=$(jq '.score' "$JSON_DIR/smer.json")

PES=$(awk -v a="$MBR" -v b="$NPER" -v c="$SMER" \
'BEGIN{printf "%.2f",(a+b+c)/3}')

cat > "$JSON_DIR/pes.json" <<EOF
{
  "metric":"PES",
  "mbr":$MBR,
  "nper":$NPER,
  "smer":$SMER,
  "score":$PES
}
EOF

cat > "$TXT_DIR/pes.txt" <<EOF
==========================================
Prevention Effectiveness Score
==========================================

Manifest Blocking Rate      : $MBR
Network Policy Enforcement  : $NPER
Secrets Management          : $SMER

------------------------------------------

PES                         : $PES
EOF

cat "$TXT_DIR/pes.txt"