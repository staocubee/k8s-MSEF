#!/usr/bin/env bash
# MSEFv2 MBR = seeded mutation corpus + explicit admission oracle.
# Env: MSEF_FUZZ_SEED (default 20261012; record it with the results), MSEF_FUZZ_COUNT (default 100)
# The v1 static manifests remain in k8s/insecure-manifests/ for reference only.
set -euo pipefail
exec python3 "$(dirname "$0")/measure_admission.py" mbr --seed "${MSEF_FUZZ_SEED:-20261012}" --count "${MSEF_FUZZ_COUNT:-100}"
