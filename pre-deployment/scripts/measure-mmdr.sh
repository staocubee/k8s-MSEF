#!/bin/bash

#############################################################
# MSEF
# Manifest Misconfiguration Detection Rate (MMDR)
#############################################################

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NORMALIZED="$ROOT_DIR/normalized"
GROUND="$ROOT_DIR/ground-truth"
METRICS="$ROOT_DIR/metrics"

mkdir -p "$METRICS"

echo "=========================================="
echo "MMDR Evaluation"
echo "=========================================="

#############################################################
# Ground Truth
#############################################################

KNOWN=$(jq '.known_misconfigurations | length' \
"$GROUND/manifests.json")

#############################################################
# Trivy
#############################################################

TRIVY_FOUND=$(jq '.manifests | length' \
"$NORMALIZED/trivy.json")

TRIVY_MMDR=$(awk "BEGIN {

if($KNOWN==0)

print 0;

else

printf \"%.2f\",$TRIVY_FOUND/$KNOWN

}")

#############################################################
# Snyk
#############################################################

SNYK_FOUND=$(jq '.manifests | length' \
"$NORMALIZED/snyk.json")

SNYK_MMDR=$(awk "BEGIN {

if($KNOWN==0)

print 0;

else

printf \"%.2f\",$SNYK_FOUND/$KNOWN

}")

#############################################################

cat > "$METRICS/mmdr.json" <<EOF
{
  "metric":"MMDR",

  "known":$KNOWN,

  "trivy":{
      "detected":$TRIVY_FOUND,
      "score":$TRIVY_MMDR
  },

  "snyk":{
      "detected":$SNYK_FOUND,
      "score":$SNYK_MMDR
  }
}
EOF

echo
cat "$METRICS/mmdr.json"
echo