#!/usr/bin/env bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Metric:
# Integrity Effectiveness Score (IES)
#
# IES = SPR
#
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"

###############################################################################

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="$RESULTS_DIR/json"

TXT_DIR="$RESULTS_DIR/txt"

mkdir -p "$JSON_DIR" "$TXT_DIR"

###############################################################################

if [[ ! -f "$JSON_DIR/spr.json" ]]; then

    echo "Missing:"
    echo "  $JSON_DIR/spr.json"

    exit 1

fi

###############################################################################

SPR=$(jq -r '.score' "$JSON_DIR/spr.json")

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/ies.json" <<EOF
{
  "metric":"IES",
  "spr":$SPR,
  "score":$SPR
}
EOF

###############################################################################
# TXT
###############################################################################

cat > "$TXT_DIR/ies.txt" <<EOF
==========================================
Integrity Effectiveness Score (IES)
==========================================

Supply-Chain Policy Rejection Rate : $SPR

------------------------------------------

IES                                : $SPR

Generated : $(date)

EOF

cat "$JSON_DIR/ies.json"