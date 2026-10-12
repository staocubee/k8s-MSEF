#!/usr/bin/env bash
# Print a metric already produced by its harness; never re-measure, never impute.
report_metric() {
  local name="$1" file="$2"
  [[ -f "$file" ]] || { echo "[!] $name: $file not found - run its harness first" >&2; exit 1; }
  echo "[i] $name (from $(jq -r '.run_id // "unknown run"' "$file"))"
  jq . "$file"
}
