#!/bin/bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Master Evaluation Script
#
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

mkdir -p \
"$RESULTS_DIR" \
"$RESULTS_DIR/json" \
"$RESULTS_DIR/txt" \
"$RESULTS_DIR/logs"

###############################################################################

echo "======================================================="
echo " Multi-Layer Security Evaluation Framework (MSEF)"
echo " Kubernetes Security Evaluation"
echo "======================================================="
echo "Started : $(date)"
echo

###############################################################################
# Prevention Layer
###############################################################################

echo "========== Prevention Layer =========="

scripts/measure-mbr.sh
echo

scripts/measure-nper.sh
echo

scripts/measure-smer.sh
echo

scripts/measure-pes.sh
echo

###############################################################################
# Integrity Layer
###############################################################################

echo "========== Integrity Layer =========="

scripts/measure-spr.sh
echo

scripts/measure-ies.sh
echo

###############################################################################
# Detection Layer
###############################################################################

echo "========== Detection Layer =========="

scripts/measure-rdr.sh
echo

scripts/measure-mttd.sh
echo

scripts/measure-fpr.sh
echo

scripts/measure-rrsr.sh
echo

scripts/measure-des.sh
echo

###############################################################################
# Reports
###############################################################################

echo "========== Generating Reports =========="

scripts/generate-security-report.sh

echo

scripts/generate-html-report.sh

###############################################################################

echo
echo "======================================================="
echo " Evaluation Completed Successfully"
echo "======================================================="
echo
echo "Reports Generated:"
echo "  results/txt/"
echo "  results/json/"
echo "  results/logs/"
echo "  results/index.html"
echo
echo "Completed : $(date)"