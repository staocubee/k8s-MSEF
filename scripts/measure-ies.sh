#!/usr/bin/env bash

#############################################################
# Integrity Effectiveness Score (IES)
#############################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"
JSON_DIR="${RESULTS_DIR}/json"
TXT_DIR="${RESULTS_DIR}/txt"

mkdir -p "$JSON_DIR" "$TXT_DIR"

SPR=$(jq '.trivy.score' "$JSON_DIR/spr.json")

cat > "$JSON_DIR/ies.json" <<EOF
{
  "metric":"IES",
  "spr":$SPR,
  "score":$SPR
}
EOF

cat > "$TXT_DIR/ies.txt" <<EOF
==========================================
Integrity Effectiveness Score
==========================================

Supply Chain Protection Rate : $SPR

------------------------------------------

IES                          : $SPR
EOF

cat "$TXT_DIR/ies.txt"