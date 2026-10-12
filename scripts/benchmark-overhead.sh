#!/usr/bin/env bash
# Wrapper: admission latency + resource footprint for the current cluster state.
# Usage: scripts/benchmark-overhead.sh --config C5 [bench_admission.py options]
set -euo pipefail
exec python3 "$(dirname "$0")/bench_admission.py" "$@"
