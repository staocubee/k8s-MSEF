#!/usr/bin/env bash
# Superseded in MSEFv2: RDR, RRSR, MTTD, MTTC and OFPR are now produced together,
# per scenario, by scripts/run-runtime-suite.sh (+ compute_runtime_metrics.py),
# so that detection and containment are measured on the same events.
set -euo pipefail
echo "[i] measure-rdr.sh is superseded; running scripts/run-runtime-suite.sh $*" >&2
exec "$(dirname "$0")/run-runtime-suite.sh" "$@"
