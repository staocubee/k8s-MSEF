#!/usr/bin/env bash
# ==============================================================================
# Multi-Layer Security Evaluation Framework (MSEF)
# Script: scripts/measure-pes.sh
# Purpose: Compute Weighted Prevention Effectiveness Score (PES)
# ==============================================================================

set -euo pipefail

# Fail rather than impute: a missing or null input must never become a score.
require_metric() {
  local file="$1" key="$2" v
  [[ -f "$file" ]] || { echo "[!] missing input $file - run its harness first" >&2; exit 1; }
  v="$(jq -r "$key" "$file")"
  [[ -n "$v" && "$v" != "null" ]] || { echo "[!] $file has no value at $key (run invalid or incomplete)" >&2; exit 1; }
  echo "$v"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/scripts/lib/common.sh"
source "${PROJECT_ROOT}/scripts/lib/output.sh"

RESULTS_DIR="${PROJECT_ROOT}/results"
JSON_DIR="${RESULTS_DIR}/json"
TXT_DIR="${RESULTS_DIR}/txt"

mkdir -p "${JSON_DIR}" "${TXT_DIR}"

OUTPUT_JSON="${JSON_DIR}/pes.json"
OUTPUT_TXT="${TXT_DIR}/pes.txt"

# Weights: Manifest (0.40), Network (0.30), Secrets (0.30)
W_MBR=0.40
W_NPER=0.30
W_SMER=0.30

# Extract Component Scores from generated JSON artifacts
MBR=$(require_metric "${JSON_DIR}/mbr.json" '.score')
NPER=$(require_metric "${JSON_DIR}/nper.json" '.score')
SMER=$(require_metric "${JSON_DIR}/smer.json" '.score')

# Compute Weighted PES using Python
CALC_JSON=$(python3 -c "
w_mbr, w_nper, w_smer = ${W_MBR}, ${W_NPER}, ${W_SMER}
mbr, nper, smer = float('${MBR}'), float('${NPER}'), float('${SMER}')

pes = (w_mbr * mbr) + (w_nper * nper) + (w_smer * smer)
pes_pct = pes * 100

import json
print(json.dumps({
    'pes': round(pes, 4),
    'pes_percentage': round(pes_pct, 2),
    'components': {'mbr': mbr, 'nper': nper, 'smer': smer},
    'weights': {'w_mbr': w_mbr, 'w_nper': w_nper, 'w_smer': w_smer}
}))
")

PES=$(echo "${CALC_JSON}" | jq -r '.pes')
PES_PCT=$(echo "${CALC_JSON}" | jq -r '.pes_percentage')

cat <<EOF > "${OUTPUT_JSON}"
{
  "metric": "PES",
  "score": ${PES},
  "percentage": ${PES_PCT},
  "weighting_model": "linear_convex_combination",
  "weights": {
    "mbr": ${W_MBR},
    "nper": ${W_NPER},
    "smer": ${W_SMER}
  },
  "components": {
    "mbr": ${MBR},
    "nper": ${NPER},
    "smer": ${SMER}
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat <<EOF > "${OUTPUT_TXT}"
=== Prevention Effectiveness Score (PES) ===
Score: ${PES} (${PES_PCT}%)
Weighting: 0.40*MBR + 0.30*NPER + 0.30*SMER
MBR:  ${MBR}
NPER: ${NPER}
SMER: ${SMER}
EOF

log_success "Weighted PES Calculation Complete: ${PES} (${PES_PCT}%)"