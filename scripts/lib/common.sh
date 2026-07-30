#!/usr/bin/env bash

###############################################################################
# MSEF Common Library
###############################################################################

set -euo pipefail

###############################################################################
# Project paths
###############################################################################

# Set SCRIPT_DIR to the parent 'scripts/' directory, not 'scripts/lib/'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Project root is one level above 'scripts/'
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="$RESULTS_DIR/json"
TXT_DIR="$RESULTS_DIR/txt"
LOG_DIR="$RESULTS_DIR/logs"
TMP_DIR="$RESULTS_DIR/tmp"

mkdir -p \
    "$RESULTS_DIR" \
    "$JSON_DIR" \
    "$TXT_DIR" \
    "$LOG_DIR" \
    "$TMP_DIR"