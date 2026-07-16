#!/bin/bash

#############################################################
# MSEF
# Infrastructure-as-Code Detection Rate (IDR)
#############################################################

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NORMALIZED="$ROOT_DIR/normalized"
GROUND="$ROOT_DIR/ground-truth"
METRICS="$ROOT_DIR/metrics"

mkdir -p "$METRICS"

echo "=========================================="
echo "IDR Evaluation"
echo "=========================================="

#############################################################
# Ground Truth
#############################################################

KNOWN=$(jq '.known_iac_issues | length' \
"$GROUND/terraform.json")

#############################################################
# Trivy
#############################################################

TRIVY_FOUND=$(jq '.terraform | length' \
"$NORMALIZED/trivy.json")

TRIVY_IDR=$(awk "BEGIN {

if($KNOWN==0)

print 0;

else

printf \"%.2f\",$TRIVY_FOUND/$KNOWN

}")

#############################################################
# Snyk
#############################################################

SNYK_FOUND=$(jq '.terraform | length' \
"$NORMALIZED/snyk.json")

SNYK_IDR=$(awk "BEGIN {

if($KNOWN==0)

print 0;

else

printf \"%.2f\",$SNYK_FOUND/$KNOWN

}")

#############################################################
# Save Results
#############################################################

cat > "$METRICS/idr.json" <<EOF
{
  "metric":"IDR",

  "known":$KNOWN,

  "trivy":{
      "detected":$TRIVY_FOUND,
      "score":$TRIVY_IDR
  },

  "snyk":{
      "detected":$SNYK_FOUND,
      "score":$SNYK_IDR
  }
}
EOF

echo
cat "$METRICS/idr.json"
echo