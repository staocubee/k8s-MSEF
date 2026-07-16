#!/bin/bash

#############################################################
# MSEF
# Secret Detection Rate (SDR)
#############################################################

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NORMALIZED="$ROOT_DIR/normalized"
GROUND="$ROOT_DIR/ground-truth"
METRICS="$ROOT_DIR/metrics"

mkdir -p "$METRICS"

echo "=========================================="
echo "SDR Evaluation"
echo "=========================================="

#############################################################
# Ground Truth
#############################################################

KNOWN=$(jq '.known_secrets | length' \
"$GROUND/secrets.json")

#############################################################
# Trivy
#############################################################

TRIVY_FOUND=$(jq '.secrets | length' \
"$NORMALIZED/trivy.json")

TRIVY_SDR=$(awk "BEGIN {

if($KNOWN==0)

print 0;

else

printf \"%.2f\",$TRIVY_FOUND/$KNOWN

}")

#############################################################
# Snyk
#############################################################

SNYK_FOUND=$(jq '.secrets | length' \
"$NORMALIZED/snyk.json")

SNYK_SDR=$(awk "BEGIN {

if($KNOWN==0)

print 0;

else

printf \"%.2f\",$SNYK_FOUND/$KNOWN

}")

#############################################################
# Save Results
#############################################################

cat > "$METRICS/sdr.json" <<EOF
{
  "metric":"SDR",

  "known":$KNOWN,

  "trivy":{
      "detected":$TRIVY_FOUND,
      "score":$TRIVY_SDR
  },

  "snyk":{
      "detected":$SNYK_FOUND,
      "score":$SNYK_SDR
  }
}
EOF

echo
cat "$METRICS/sdr.json"
echo