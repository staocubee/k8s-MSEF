#!/bin/bash

#############################################################
# MSEF
# Mean Scan Time (MST)
#############################################################

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TIMINGS="$ROOT_DIR/timings"
METRICS="$ROOT_DIR/metrics"

mkdir -p "$METRICS"

echo "=========================================="
echo "Mean Scan Time Evaluation"
echo "=========================================="

###############################################
# Safe jq helper
###############################################

get_time() {

FILE=$1
FIELD=$2

jq -r ".$FIELD // 0" "$FILE" 2>/dev/null || echo 0

}

###############################################
# Trivy
###############################################

TRIVY_IMAGE=$(get_time "$TIMINGS/trivy-times.json" image)
TRIVY_MANIFEST=$(get_time "$TIMINGS/trivy-times.json" manifest)
TRIVY_TERRAFORM=$(get_time "$TIMINGS/trivy-times.json" terraform)
TRIVY_SECRET=$(get_time "$TIMINGS/trivy-times.json" secret)
TRIVY_DEP=$(get_time "$TIMINGS/trivy-times.json" dependency)

TRIVY_MST=$(awk \
-v a="$TRIVY_IMAGE" \
-v b="$TRIVY_MANIFEST" \
-v c="$TRIVY_TERRAFORM" \
-v d="$TRIVY_SECRET" \
-v e="$TRIVY_DEP" \
'BEGIN{
printf "%.2f",(a+b+c+d+e)/5
}')

###############################################
# Snyk
###############################################

SNYK_IMAGE=$(get_time "$TIMINGS/snyk-times.json" image)
SNYK_MANIFEST=$(get_time "$TIMINGS/snyk-times.json" manifest)
SNYK_TERRAFORM=$(get_time "$TIMINGS/snyk-times.json" terraform)
SNYK_SECRET=$(get_time "$TIMINGS/snyk-times.json" secret)
SNYK_DEP=$(get_time "$TIMINGS/snyk-times.json" dependency)

SNYK_MST=$(awk \
-v a="$SNYK_IMAGE" \
-v b="$SNYK_MANIFEST" \
-v c="$SNYK_TERRAFORM" \
-v d="$SNYK_SECRET" \
-v e="$SNYK_DEP" \
'BEGIN{
printf "%.2f",(a+b+c+d+e)/5
}')

###############################################

cat > "$METRICS/mst.json" <<EOF
{
  "metric":"MST",
  "unit":"seconds",

  "trivy":{
    "image":$TRIVY_IMAGE,
    "manifest":$TRIVY_MANIFEST,
    "terraform":$TRIVY_TERRAFORM,
    "secret":$TRIVY_SECRET,
    "dependency":$TRIVY_DEP,
    "mean":$TRIVY_MST
  },

  "snyk":{
    "image":$SNYK_IMAGE,
    "manifest":$SNYK_MANIFEST,
    "terraform":$SNYK_TERRAFORM,
    "secret":$SNYK_SECRET,
    "dependency":$SNYK_DEP,
    "mean":$SNYK_MST
  }

}
EOF

echo
cat "$METRICS/mst.json"
echo