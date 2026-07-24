#!/bin/bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Metric:
# Manifest Blocking Rate (MBR)
#
# MBR = Blocked Insecure Manifests / Total Insecure Manifests
#
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

###############################################################################
# Configuration
###############################################################################

MANIFEST_DIR="${MANIFEST_DIR:-k8s/insecure-manifests}"

TARGET_NS="${TARGET_NS:-hardened}"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="${RESULTS_DIR}/json"

TXT_DIR="${RESULTS_DIR}/txt"

LOG_DIR="${RESULTS_DIR}/logs"

mkdir -p "$JSON_DIR" "$TXT_DIR" "$LOG_DIR"

DETAILS="$LOG_DIR/mbr-details.log"

> "$DETAILS"

###############################################################################

echo "=========================================="

echo "Manifest Blocking Rate (MBR)"

echo "=========================================="

TOTAL=0

BLOCKED=0

ALLOWED=0

###############################################################################

for FILE in "$MANIFEST_DIR"/*.yaml
do

    [ -e "$FILE" ] || continue

    TOTAL=$((TOTAL+1))

    NAME=$(basename "$FILE")

    echo "Testing: $NAME"

    OUTPUT=$(kubectl apply \
        --dry-run=server \
        -f "$FILE" \
        -n "$TARGET_NS" \
        2>&1 || true)

    if echo "$OUTPUT" | grep -Eiq \
        "forbidden|denied|violation|disallowed|admission webhook|required|failed"
    then

        RESULT="BLOCKED"

        BLOCKED=$((BLOCKED+1))

    else

        RESULT="ALLOWED"

        ALLOWED=$((ALLOWED+1))

    fi

cat >> "$DETAILS" <<EOF
Manifest: $NAME
Result: $RESULT
----------------------------------------
EOF

done

###############################################################################

if [ "$TOTAL" -eq 0 ]; then

    echo "No manifests found."

    exit 1

fi

###############################################################################

MBR=$(awk -v b="$BLOCKED" -v t="$TOTAL" 'BEGIN{printf "%.2f",b/t}')

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/mbr.json" <<EOF
{
    "metric":"MBR",
    "total_manifests":$TOTAL,
    "blocked":$BLOCKED,
    "allowed":$ALLOWED,
    "score":$MBR
}
EOF

###############################################################################
# TXT
###############################################################################

cat > "$TXT_DIR/mbr.txt" <<EOF
==========================================
Manifest Blocking Rate
==========================================

Total Manifests : $TOTAL

Blocked         : $BLOCKED

Allowed         : $ALLOWED

MBR             : $MBR

Generated : $(date)

EOF

cat "$JSON_DIR/mbr.json"