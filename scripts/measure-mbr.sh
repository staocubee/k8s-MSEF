#!/usr/bin/env bash

set -euo pipefail

source scripts/lib/common.sh
source scripts/lib/kubernetes.sh
source scripts/lib/validation.sh
source scripts/lib/metrics.sh
source scripts/lib/output.sh

init_framework

print_banner "Manifest Blocking Rate (MBR)"

TARGET_NS="${TARGET_NS:-hardened}"
MANIFEST_DIR="${MANIFEST_DIR:-k8s/insecure-manifests}"

require_namespace "$TARGET_NS"
require_gatekeeper

TOTAL=0
BLOCKED=0
ALLOWED=0

DETAILS="$LOG_DIR/mbr-details.log"
: > "$DETAILS"

for FILE in "$MANIFEST_DIR"/*.yaml
do

    TOTAL=$((TOTAL+1))

    NAME=$(basename "$FILE")

    log_info "Testing $NAME"

    OUTPUT=$(apply_dry_run "$FILE" "$TARGET_NS" || true)

    if admission_blocked "$OUTPUT"
    then

        RESULT="BLOCKED"

        BLOCKED=$((BLOCKED+1))

    else

        RESULT="ALLOWED"

        ALLOWED=$((ALLOWED+1))

    fi

    printf "%s : %s\n" "$NAME" "$RESULT" >> "$DETAILS"

done

MBR=$(score "$BLOCKED" "$TOTAL")

cat > "$JSON_DIR/mbr.json" <<EOF
{
  "framework":"Kubernetes MSEF",
  "metric":"MBR",
  "timestamp":"$(timestamp)",
  "total":$TOTAL,
  "blocked":$BLOCKED,
  "allowed":$ALLOWED,
  "score":$MBR
}
EOF

cat "$JSON_DIR/mbr.json"