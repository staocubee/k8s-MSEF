#!/usr/bin/env bash

###############################################################################
# False Positive Rate (FPR)
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/kubernetes.sh"
source "$SCRIPT_DIR/lib/falco.sh"

###############################################################################

TEST_DIR="${TEST_DIR:-$PROJECT_ROOT/k8s/benign}"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="$RESULTS_DIR/json"
TXT_DIR="$RESULTS_DIR/txt"
LOG_DIR="$RESULTS_DIR/logs"

mkdir -p \
    "$JSON_DIR" \
    "$TXT_DIR" \
    "$LOG_DIR"

DETAILS="$LOG_DIR/fpr-details.log"

> "$DETAILS"

###############################################################################

echo "=========================================="
echo "False Positive Rate (FPR)"
echo "=========================================="

require_namespace baseline
require_namespace falco

###############################################################################

TOTAL=0
FALSE_ALERTS=0

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

    kubectl wait \
        --for=condition=Ready \
        pod/"$POD" \
        -n baseline \
        --timeout=60s >/dev/null 2>&1 || true

    sleep 20

    if falco_detected "$POD|$NAME"
    then

        RESULT="FALSE ALERT"

        FALSE_ALERTS=$((FALSE_ALERTS+1))

    else

        RESULT="NO ALERT"

    fi

cat >> "$DETAILS" <<EOF
Workload : $NAME
Result   : $RESULT
----------------------------------------
EOF

    kubectl delete \
        -f "$FILE" \
        --ignore-not-found >/dev/null 2>&1 || true

done

###############################################################################

[[ "$TOTAL" -gt 0 ]] || fail "No benign workloads found."

###############################################################################

FPR=$(calculate_ratio "$FALSE_ALERTS" "$TOTAL")

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/fpr.json" <<EOF
{
  "metric":"FPR",
  "benign_workloads":$TOTAL,
  "false_alerts":$FALSE_ALERTS,
  "score":$FPR
}
EOF

###############################################################################
# TXT
###############################################################################

cat > "$TXT_DIR/fpr.txt" <<EOF
==========================================
False Positive Rate
==========================================

Benign Workloads : $TOTAL
False Alerts     : $FALSE_ALERTS

FPR              : $FPR

Generated : $(date)

EOF

cat "$TXT_DIR/fpr.txt"