#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

mkdir -p \
"$RESULTS_DIR"/{json,txt,logs}

section() {

    echo
    echo "=================================================="
    echo "$1"
    echo "=================================================="

}

run_metric() {

    local SCRIPT="$1"

    echo

    echo "Running $(basename "$SCRIPT")"

    "$SCRIPT"

}

banner "Multi-Layer Security Evaluation Framework"

echo "Started: $(date)"

section "Prevention Layer"

run_metric "$SCRIPT_DIR/measure-mbr.sh"
run_metric "$SCRIPT_DIR/measure-nper.sh"
run_metric "$SCRIPT_DIR/measure-smer.sh"
run_metric "$SCRIPT_DIR/measure-pes.sh"

section "Integrity Layer"

run_metric "$SCRIPT_DIR/measure-spr.sh"
run_metric "$SCRIPT_DIR/measure-ies.sh"

section "Detection Layer"

run_metric "$SCRIPT_DIR/measure-rdr.sh"
run_metric "$SCRIPT_DIR/measure-mttd.sh"
run_metric "$SCRIPT_DIR/measure-fpr.sh"
run_metric "$SCRIPT_DIR/measure-rrsr.sh"
run_metric "$SCRIPT_DIR/measure-des.sh"

section "Generating Reports"

run_metric "$SCRIPT_DIR/generate-security-report.sh"
run_metric "$SCRIPT_DIR/generate-html-report.sh"

banner "Evaluation Completed"

echo

echo "Results"

echo "  $RESULTS_DIR/txt"

echo "  $RESULTS_DIR/json"

echo "  $RESULTS_DIR/logs"

echo "  $RESULTS_DIR/index.html"

echo

echo "Completed: $(date)"