#!/bin/bash

#############################################################
# MSEF
# False Negative Rate (FNR)
#############################################################

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

METRICS="$ROOT_DIR/metrics"

echo "=========================================="
echo "False Negative Rate (FNR)"
echo "=========================================="

#############################################################
# Read metrics
#############################################################

CVDR_KNOWN=$(jq '.known' "$METRICS/cvdr.json")
MMDR_KNOWN=$(jq '.known' "$METRICS/mmdr.json")
IDR_KNOWN=$(jq '.known' "$METRICS/idr.json")
WFDR_KNOWN=$(jq '.known' "$METRICS/wfdr.json")
SDR_KNOWN=$(jq '.known' "$METRICS/sdr.json")

#############################################################
# Totals
#############################################################

KNOWN=$((

CVDR_KNOWN +

MMDR_KNOWN +

IDR_KNOWN +

WFDR_KNOWN +

SDR_KNOWN

))

#############################################################
# Trivy
#############################################################

TRIVY_FOUND=$((

$(jq '.trivy.detected' "$METRICS/cvdr.json") +

$(jq '.trivy.detected' "$METRICS/mmdr.json") +

$(jq '.trivy.detected' "$METRICS/idr.json") +

$(jq '.trivy.detected' "$METRICS/wfdr.json") +

$(jq '.trivy.detected' "$METRICS/sdr.json")

))

#############################################################
# Snyk
#############################################################

SNYK_FOUND=$((

$(jq '.snyk.detected' "$METRICS/cvdr.json") +

$(jq '.snyk.detected' "$METRICS/mmdr.json") +

$(jq '.snyk.detected' "$METRICS/idr.json") +

$(jq '.snyk.detected' "$METRICS/wfdr.json") +

$(jq '.snyk.detected' "$METRICS/sdr.json")

))

#############################################################
# Missed
#############################################################

TRIVY_MISSED=$((KNOWN-TRIVY_FOUND))
SNYK_MISSED=$((KNOWN-SNYK_FOUND))

#############################################################
# Score
#############################################################

calc_score(){

awk -v m="$1" -v k="$2" '
BEGIN{

if(k==0)

printf "0.00";

else

printf "%.2f", m/k

}'
}

TRIVY_SCORE=$(calc_score "$TRIVY_MISSED" "$KNOWN")
SNYK_SCORE=$(calc_score "$SNYK_MISSED" "$KNOWN")

#############################################################

cat > "$METRICS/fnr.json" <<EOF
{
  "metric":"FNR",

  "known":$KNOWN,

  "trivy":{

      "detected":$TRIVY_FOUND,

      "missed":$TRIVY_MISSED,

      "score":$TRIVY_SCORE

  },

  "snyk":{

      "detected":$SNYK_FOUND,

      "missed":$SNYK_MISSED,

      "score":$SNYK_SCORE

  }
}
EOF

echo
cat "$METRICS/fnr.json"
echo