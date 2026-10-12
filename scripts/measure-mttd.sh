#!/usr/bin/env bash
# MTTD is produced by its harness (runtime suite or SPR); this only reports it.
set -euo pipefail
source "$(dirname "$0")/lib/report_metric.sh"
report_metric "MTTD" "$(cd "$(dirname "$0")/.." && pwd)/results/json/mttd.json"
