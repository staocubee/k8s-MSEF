#!/bin/bash
set -euo pipefail

MANIFEST="${MANIFEST:-k8s/integrity-tests/unsigned-test.yaml}"
TOTAL="${TOTAL:-10}"
RESULTS_DIR="${RESULTS_DIR:-results}"

mkdir -p "$RESULTS_DIR"

BLOCKED=0
ALLOWED=0

echo "===== Signature Policy Rejection Rate Experiment ====="
echo "Unsigned Manifest: $MANIFEST"
echo ""

for i in $(seq 1 "$TOTAL"); do
  TMP_FILE="/tmp/unsigned-test-$i.yaml"

  sed "s/name: unsigned-test/name: unsigned-test-$i/g" "$MANIFEST" > "$TMP_FILE"

  OUTPUT=$(kubectl apply --dry-run=server -f "$TMP_FILE" 2>&1 || true)

  if echo "$OUTPUT" | grep -Eiq "signature|cosign|attestor|verify|verified|denied|failed|no matching signatures|not found"; then
    BLOCKED=$((BLOCKED + 1))
    echo "Attempt $i: BLOCKED"
  else
    ALLOWED=$((ALLOWED + 1))
    echo "Attempt $i: ALLOWED"
  fi

  echo "$OUTPUT" >> "$RESULTS_DIR/spr-details.log"
  echo "--------------------------------" >> "$RESULTS_DIR/spr-details.log"
done

SPR=$(echo "scale=2; $BLOCKED / $TOTAL" | bc)

echo ""
echo "===== Experiment Result ====="
echo "Blocked Unsigned Images: $BLOCKED"
echo "Allowed Unsigned Images: $ALLOWED"
echo "Total Unsigned Image Attempts: $TOTAL"
echo "SPR = $SPR"
echo "Timestamp: $(date)"