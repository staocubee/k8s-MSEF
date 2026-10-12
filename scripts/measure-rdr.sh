#!/usr/bin/env bash
# Runs the Layer 4 runtime suite ONCE. It writes rdr.json, rrsr.json, mttd.json
# and fpr.json together; measure-mttd/-fpr/-rrsr.sh only report those files.
# Env: MSEF_RUNTIME_REPEATS (default 1), MSEF_CONFIG_LABEL (default C5)
set -euo pipefail
exec "$(dirname "$0")/run-runtime-suite.sh" --repeats "${MSEF_RUNTIME_REPEATS:-1}" --config-label "${MSEF_CONFIG_LABEL:-C5}"
