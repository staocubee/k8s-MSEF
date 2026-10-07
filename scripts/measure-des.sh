#!/usr/bin/env bash

###############################################################################
#
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Metric:
#
# Detection Effectiveness Score (DES)
#
# DES =
#
# ( RDR + (1 - FPR) + Normalized MTTD + RRSR ) / 4
#
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/metrics.sh"

###############################################################################
# Configuration
###############################################################################

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="$RESULTS_DIR/json"
TXT_DIR="$RESULTS_DIR/txt"

mkdir -p "$JSON_DIR" "$TXT_DIR"

###############################################################################

banner "Detection Effectiveness Score (DES)"

###############################################################################
# Required metrics
###############################################################################

require_file "$JSON_DIR/rdr.json"
require_file "$JSON_DIR/mttd.json"
require_file "$JSON_DIR/fpr.json"
require_file "$JSON_DIR/rrsr.json"

###############################################################################
# Load metrics
###############################################################################

RDR=$(jq '.score' "$JSON_DIR/rdr.json")
FPR=$(jq '.score' "$JSON_DIR/fpr.json")
MTTD=$(jq '.score' "$JSON_DIR/mttd.json")
TOTAL_TIME=$(jq '.total_time_seconds' "$JSON_DIR/mttd.json")
RRSR=$(jq '.score' "$JSON_DIR/rrsr.json")

###############################################################################
# Normalize MTTD
#
# Formula:
#
# Normalized MTTD = 1 - (MTTD / Total Observation Time)
#
# Lower detection time gives higher score.
###############################################################################

NORM_MTTD=$(awk \
    -v t="$MTTD" \
    -v max="$TOTAL_TIME" '
BEGIN{

    if(max <= 0){
        print "0.00"
        exit
    }

    value = 1 - (t / max)

    if(value < 0)
        value = 0

    if(value > 1)
        value = 1

    printf "%.2f", value

}')

###############################################################################
# Normalize FPR
#
# Smaller is better.
###############################################################################

NORM_FPR=$(awk \
    -v f="$FPR" '
BEGIN{

    printf "%.2f", 1-f

}')

###############################################################################
# DES
###############################################################################

DES=$(awk \
-v rdr="$RDR" \
-v fpr="$NORM_FPR" \
-v mttd="$NORM_MTTD" \
-v rrsr="$RRSR" '
BEGIN{

    printf "%.2f",
    (rdr + fpr + mttd + rrsr)/4

}')

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/des.json" <<EOF
{
  "metric":"DES",
  "runtime_detection_rate":$RDR,
  "false_positive_rate":$FPR,
  "normalized_false_positive":$NORM_FPR,
  "mean_time_to_detect":$MTTD,
  "normalized_mttd":$NORM_MTTD,
  "runtime_response_success_rate":$RRSR,
  "score":$DES
}
EOF

###############################################################################
# TXT
###############################################################################

cat > "$TXT_DIR/des.txt" <<EOF
==========================================
Detection Effectiveness Score
==========================================

Runtime Detection Rate
$RDR

Operational False Positive Rate
$OFPR

Normalized Operational False Positive Rate
$NORM_FPR

Mean Time To Detect
${MTTD} seconds

Normalized MTTD
$NORM_MTTD

Runtime Response Success Rate
$RRSR

------------------------------------------

DES

$DES

Generated

$(date)

EOF

###############################################################################

cat "$TXT_DIR/des.txt"