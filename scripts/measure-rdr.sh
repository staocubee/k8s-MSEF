#!/usr/bin/env bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Runtime Detection Rate (RDR)
#
# RDR = Detected Runtime Attacks / Total Runtime Attacks
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/kubernetes.sh"
source "$SCRIPT_DIR/lib/falco.sh"

###############################################################################
# Configuration
###############################################################################

TEST_DIR="${TEST_DIR:-$PROJECT_ROOT/k8s/runtime-tests}"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="$RESULTS_DIR/json"
TXT_DIR="$RESULTS_DIR/txt"
LOG_DIR="$RESULTS_DIR/logs"

mkdir -p \
    "$JSON_DIR" \
    "$TXT_DIR" \
    "$LOG_DIR"

DETAILS="$LOG_DIR/rdr-details.log"

> "$DETAILS"

###############################################################################

echo "=========================================="
echo "Runtime Detection Rate (RDR)"
echo "=========================================="

require_namespace baseline
require_namespace falco

###############################################################################

TOTAL=0
DETECTED=0

ATTACK_RESULTS=""

###############################################################################

for FILE in "$TEST_DIR"/*.yaml
do

    [[ -f "$FILE" ]] || continue

    TOTAL=$((TOTAL+1))

    NAME=$(basename "$FILE" .yaml)

    POD=$(kubectl create \
        --dry-run=client \
        -f "$FILE" \
        -o jsonpath='{.metadata.name}')

    echo
    echo "Running: $NAME"

    kubectl delete \
        -f "$FILE" \
        --ignore-not-found >/dev/null 2>&1 || true

    kubectl apply -f "$FILE" >/dev/null

    START=$(date +%s)

    kubectl wait \
        --for=condition=Ready \
        pod/"$POD" \
        -n baseline \
        --timeout=60s >/dev/null 2>&1 || true

    sleep 20

    TIME=$(measure_detection_time "$START")

    if falco_detected "$POD|$NAME"
    then

        FOUND=true

        DETECTED=$((DETECTED+1))

        echo "Detected"

    else

        FOUND=false

        echo "Not Detected"

    fi

    ATTACK_RESULTS="${ATTACK_RESULTS}
{
  \"name\":\"${NAME}\",
  \"pod\":\"${POD}\",
  \"detected\":${FOUND},
  \"time_seconds\":${TIME}
},"

cat >> "$DETAILS" <<EOF
Attack : $NAME
Pod    : $POD
Detected : $FOUND
Time     : ${TIME}s
----------------------------------------
EOF

    kubectl delete \
        -f "$FILE" \
        --ignore-not-found >/dev/null 2>&1 || true

done

###############################################################################

[[ "$TOTAL" -gt 0 ]] || fail "No runtime tests found."

###############################################################################

RDR=$(calculate_ratio "$DETECTED" "$TOTAL")

###############################################################################
# Remove trailing comma
###############################################################################

ATTACK_RESULTS=$(echo "$ATTACK_RESULTS" | sed '$ s/,$//')

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/rdr.json" <<EOF
{
  "metric":"RDR",
  "total_attacks":$TOTAL,
  "detected":$DETECTED,
  "score":$RDR,
  "attacks":[
$ATTACK_RESULTS
  ]
}
EOF

###############################################################################
# TXT
###############################################################################

cat > "$TXT_DIR/rdr.txt" <<EOF
==========================================
Runtime Detection Rate
==========================================

Total Runtime Attacks : $TOTAL
Detected              : $DETECTED

RDR                   : $RDR

Generated : $(date)
EOF

cat "$TXT_DIR/rdr.txt"