#!/usr/bin/env bash
# ==============================================================================
# Multi-Layer Security Evaluation Framework (MSEF)
# Script: scripts/measure-des.sh
# Purpose: Compute Detection Effectiveness Score (DES) with Exponential Latency Decay
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

OUTPUT_JSON="${JSON_DIR}/des.json"
OUTPUT_TXT="${TXT_DIR}/des.txt"

# Weights: RDR (0.35), RRSR (0.30), OFPR (0.15), MTTD Decay (0.20)
W_RDR=0.35
W_RRSR=0.30
W_OFPR=0.15
W_MTTD=0.20
LAMBDA_DECAY=0.03

# Extract Component Scores from generated JSON artifacts
RDR=$(require_metric "${JSON_DIR}/rdr.json" '.score')
RRSR=$(require_metric "${JSON_DIR}/rrsr.json" '.score')
OFPR=$(require_metric "${JSON_DIR}/fpr.json" '.score')
MTTD=$(require_metric "${JSON_DIR}/mttd.json" '.mean_time_to_detect_s')

CALC_JSON=$(python3 -c "
import math, json

w_rdr, w_rrsr, w_ofpr, w_mttd = ${W_RDR}, ${W_RRSR}, ${W_OFPR}, ${W_MTTD}
decay_const = ${LAMBDA_DECAY}

rdr = float('${RDR}')
rrsr = float('${RRSR}')
ofpr = float('${OFPR}')
mttd = float('${MTTD}')

# Exponential decay score for dwell-time detection latency
latency_score = math.exp(-decay_const * mttd)
quality_score = 1.0 - ofpr

des = (w_rdr * rdr) + (w_rrsr * rrsr) + (w_ofpr * quality_score) + (w_mttd * latency_score)
des_pct = des * 100

print(json.dumps({
    'des': round(des, 4),
    'des_percentage': round(des_pct, 2),
    'latency_decay_score': round(latency_score, 4),
    'quality_score': round(quality_score, 4),
    'components': {'rdr': rdr, 'rrsr': rrsr, 'ofpr': ofpr, 'mttd_s': mttd}
}))
")

DES=$(echo "${CALC_JSON}" | jq -r '.des')
DES_PCT=$(echo "${CALC_JSON}" | jq -r '.des_percentage')
LAT_SCORE=$(echo "${CALC_JSON}" | jq -r '.latency_decay_score')

cat <<EOF > "${OUTPUT_JSON}"
{
  "metric": "DES",
  "score": ${DES},
  "percentage": ${DES_PCT},
  "mathematical_model": "weighted_continuous_exponential_decay",
  "decay_constant_lambda": ${LAMBDA_DECAY},
  "latency_decay_component": ${LAT_SCORE},
  "weights": {
    "rdr": ${W_RDR},
    "rrsr": ${W_RRSR},
    "ofpr": ${W_OFPR},
    "latency": ${W_MTTD}
  },
  "components": {
    "rdr": ${RDR},
    "rrsr": ${RRSR},
    "ofpr": ${OFPR},
    "mttd_seconds": ${MTTD}
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat <<EOF > "${OUTPUT_TXT}"
=== Detection Effectiveness Score (DES) ===
Score: ${DES} (${DES_PCT}%)
Model: DES = 0.35*RDR + 0.30*RRSR + 0.15*(1-OFPR) + 0.20*exp(-0.03*MTTD)
RDR:                ${RDR}
RRSR:               ${RRSR}
OFPR:               ${OFPR}
MTTD:               ${MTTD} s (Decay Factor: ${LAT_SCORE})
EOF

log_success "Exponential Decay DES Calculation Complete: ${DES} (${DES_PCT}%)"