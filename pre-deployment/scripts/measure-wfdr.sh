#!/bin/bash

#############################################################
# MSEF
# Workflow Finding Detection Rate (WFDR)
#
# WFDR = Detected Workflow Issues / Known Workflow Issues
#############################################################

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GROUND="$ROOT_DIR/ground-truth"
NORMALIZED="$ROOT_DIR/normalized"
METRICS="$ROOT_DIR/metrics"

mkdir -p "$METRICS"

echo "=========================================="
echo "Workflow Finding Detection Rate (WFDR)"
echo "=========================================="

#############################################################
# Ground Truth
#############################################################

KNOWN=$(jq '.known_workflow_issues | length' \
"$GROUND/workflows.json")

#############################################################
# Trivy
#############################################################

TRIVY=$(jq '.workflows | length' \
"$NORMALIZED/trivy.json")

#############################################################
# Snyk
#############################################################

SNYK=$(jq '.workflows | length' \
"$NORMALIZED/snyk.json")

#############################################################
# Scores
#############################################################

calc_score(){

awk -v d="$1" -v k="$2" '
BEGIN{

if(k==0)

printf "0.00";

else

printf "%.2f", d/k

}'
}

TRIVY_SCORE=$(calc_score "$TRIVY" "$KNOWN")
SNYK_SCORE=$(calc_score "$SNYK" "$KNOWN")

#############################################################

cat > "$METRICS/wfdr.json" <<EOF
{
  "metric":"WFDR",

  "known":$KNOWN,

  "trivy":{
      "detected":$TRIVY,
      "score":$TRIVY_SCORE
  },

  "snyk":{
      "detected":$SNYK,
      "score":$SNYK_SCORE
  }
}
EOF

echo
cat "$METRICS/wfdr.json"
echo