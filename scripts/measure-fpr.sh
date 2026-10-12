#!/usr/bin/env bash

###############################################################################
# False Positive Rate (FPR)
###############################################################################

set -euo pipefail
shopt -s nullglob

###############################################################################
# Paths
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

###############################################################################
# Libraries
###############################################################################

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/kubernetes.sh"
source "$SCRIPT_DIR/lib/falco.sh"

###############################################################################
# Configuration
###############################################################################

RUNTIME_NS="${RUNTIME_NS:-hardened}"
FALCO_NS="${FALCO_NS:-falco}"

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

: > "$DETAILS"

###############################################################################
# Validation
###############################################################################

require_namespace "$RUNTIME_NS"
require_namespace "$FALCO_NS"

###############################################################################

echo "=========================================="
echo "False Positive Rate (FPR)"
echo "=========================================="

###############################################################################

TOTAL=0
FALSE_ALERTS=0

###############################################################################
# Execute benign workloads
###############################################################################

for FILE in "$TEST_DIR"/*.yaml
do
    [[ -f "$FILE" ]] || continue

    TOTAL=$((TOTAL + 1))

    NAME="$(basename "$FILE" .yaml)"

    echo
    echo "Running: $NAME"

    POD="$(kubectl create \
        --dry-run=client \
        -f "$FILE" \
        -o jsonpath='{.metadata.name}')"

    ###########################################################################
    # Clean previous run
    ###########################################################################

    kubectl delete \
        -f "$FILE" \
        -n "$RUNTIME_NS" \
        --ignore-not-found >/dev/null 2>&1 || true

    ###########################################################################
    # Deploy
    ###########################################################################

    kubectl apply \
        -f "$FILE" \
        -n "$RUNTIME_NS" >/dev/null

    ###########################################################################
    # Wait
    ###########################################################################

    kubectl wait \
        --for=condition=Ready \
        pod/"$POD" \
        -n "$RUNTIME_NS" \
        --timeout=60s >/dev/null 2>&1 || true

    sleep 20

    ###########################################################################
    # Detection check
    ###########################################################################

    if falco_detected "$POD|$NAME"
    then
        RESULT="FALSE ALERT"
        FALSE_ALERTS=$((FALSE_ALERTS + 1))
    else
        RESULT="NO ALERT"
    fi

    cat >> "$DETAILS" <<EOF
Workload : $NAME
Result   : $RESULT
----------------------------------------
EOF

    ###########################################################################
    # Cleanup
    ###########################################################################

    kubectl delete \
        -f "$FILE" \
        -n "$RUNTIME_NS" \
        --ignore-not-found >/dev/null 2>&1 || true

done

###############################################################################
# Validation
###############################################################################

[[ "$TOTAL" -gt 0 ]] || fail "No benign workloads found."

###############################################################################
# Calculate FPR
###############################################################################

FPR="$(calculate_ratio "$FALSE_ALERTS" "$TOTAL")"

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/fpr.json" <<EOF
{
  "framework":"Kubernetes MSEF",
  "metric":"FPR",
  "timestamp":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
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
False Positive Rate (FPR)
==========================================

Benign Workloads : $TOTAL
False Alerts     : $FALSE_ALERTS

FPR              : $FPR

Generated : $(date)

EOF

###############################################################################
# Display
###############################################################################

cat "$TXT_DIR/fpr.txt"