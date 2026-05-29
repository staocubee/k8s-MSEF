#!/bin/bash
set -euo pipefail

MANIFEST_DIR="${MANIFEST_DIR:-k8s/insecure-manifests}"
TARGET_NS="${TARGET_NS:-hardened}"
RESULTS_DIR="${RESULTS_DIR:-results}"

mkdir -p "$RESULTS_DIR"

TOTAL=0
BLOCKED=0
ALLOWED=0

echo "===== Manifest Blocking Rate Experiment ====="
echo "Manifest Directory: $MANIFEST_DIR"
echo "Target Namespace: $TARGET_NS"
echo ""

for file in "$MANIFEST_DIR"/*.yaml; do
  [ -e "$file" ] || continue

  TOTAL=$((TOTAL + 1))

  echo "Testing: $file"

  OUTPUT=$(kubectl apply --dry-run=server -f "$file" -n "$TARGET_NS" 2>&1 || true)

  if echo "$OUTPUT" | grep -Eiq "forbidden|denied|violat|disallowed|not allowed|must|required|failed"; then
    BLOCKED=$((BLOCKED + 1))
    echo "Result: BLOCKED"
  else
    ALLOWED=$((ALLOWED + 1))
    echo "Result: ALLOWED"
  fi

  echo "$OUTPUT" >> "$RESULTS_DIR/mbr-details.log"
  echo "--------------------------------" >> "$RESULTS_DIR/mbr-details.log"
done

if [ "$TOTAL" -eq 0 ]; then
  echo "ERROR: No YAML files found in $MANIFEST_DIR"
  exit 1
fi

MBR=$(echo "scale=2; $BLOCKED / $TOTAL" | bc)

echo ""
echo "===== Experiment Result ====="
echo "Total Insecure Manifests: $TOTAL"
echo "Blocked: $BLOCKED"
echo "Allowed: $ALLOWED"
echo "MBR = $MBR"
echo "Timestamp: $(date)"