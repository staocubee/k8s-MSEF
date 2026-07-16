#!/bin/bash

#############################################################
# MSEF
# Tool Agreement Rate (TAR)
#
# Measures overlap between Trivy and Snyk
# using CVE findings only.
#############################################################

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NORMALIZED="$ROOT_DIR/normalized"
METRICS="$ROOT_DIR/metrics"

mkdir -p "$METRICS"

echo "=========================================="
echo "Tool Agreement Rate (TAR)"
echo "=========================================="

#############################################################
# Extract Image CVEs
#############################################################

TRIVY_LIST=$(jq -r '.images[].id' \
"$NORMALIZED/trivy.json" | sort)

SNYK_LIST=$(jq -r '.images[].id' \
"$NORMALIZED/snyk.json" | sort)

TRIVY_TOTAL=$(echo "$TRIVY_LIST" | grep -c . || true)
SNYK_TOTAL=$(echo "$SNYK_LIST" | grep -c . || true)

#############################################################
# Shared Findings
#############################################################

SHARED=$(comm -12 \
<(echo "$TRIVY_LIST") \
<(echo "$SNYK_LIST") \
| wc -l | tr -d ' ')

TRIVY_ONLY=$((TRIVY_TOTAL - SHARED))
SNYK_ONLY=$((SNYK_TOTAL - SHARED))

UNION=$((TRIVY_TOTAL + SNYK_TOTAL - SHARED))

#############################################################

if [ "$UNION" -eq 0 ]; then
    SCORE="0.00"
else
    SCORE=$(awk "BEGIN{
        printf \"%.2f\", $SHARED/$UNION
    }")
fi

#############################################################

cat > "$METRICS/tar.json" <<EOF
{
    "metric":"TAR",

    "trivy_total":$TRIVY_TOTAL,

    "snyk_total":$SNYK_TOTAL,

    "shared":$SHARED,

    "trivy_only":$TRIVY_ONLY,

    "snyk_only":$SNYK_ONLY,

    "union":$UNION,

    "score":$SCORE
}
EOF

echo
cat "$METRICS/tar.json"
echo