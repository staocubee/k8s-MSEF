#!/usr/bin/env bash
# Thin wrapper; logic and oracle live in scripts/measure_admission.py.
set -euo pipefail
exec python3 "$(dirname "$0")/measure_admission.py" spr "$@"
