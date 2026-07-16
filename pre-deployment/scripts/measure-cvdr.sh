#!/bin/bash

#############################################################
# MSEF
# Container Vulnerability Detection Rate
#############################################################

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NORMALIZED="$ROOT_DIR/normalized"
GROUND="$ROOT_DIR/ground-truth"
METRICS="$ROOT_DIR/metrics"

mkdir -p "$METRICS"

echo "=========================================="
echo "CVDR Evaluation"
echo "=========================================="

KNOWN=$(jq '.known_vulnerabilities | length' \
"$GROUND/images.json")

#############################################################
# Trivy
#############################################################

TRIVY_FOUND=$(jq '.images | length' \
"$NORMALIZED/trivy.json")

TRIVY_CVDR=$(awk "BEGIN {

if($KNOWN==0)

print 0;

else

printf \"%.2f\",$TRIVY_FOUND/$KNOWN

}")

#############################################################
# Snyk
#############################################################

SNYK_FOUND=$(jq '.images | length' \
"$NORMALIZED/snyk.json")

SNYK_CVDR=$(awk "BEGIN {

if($KNOWN==0)

print 0;

else

printf \"%.2f\",$SNYK_FOUND/$KNOWN

}")

#############################################################

cat > "$METRICS/cvdr.json" <<EOF
{

"metric":"CVDR",

"known":$KNOWN,

"trivy":{

"detected":$TRIVY_FOUND,

"score":$TRIVY_CVDR

},

"snyk":{

"detected":$SNYK_FOUND,

"score":$SNYK_CVDR

}

}
EOF

echo

cat "$METRICS/cvdr.json"

echo