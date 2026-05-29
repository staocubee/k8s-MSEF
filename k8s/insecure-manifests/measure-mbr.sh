#!/bin/bash

TOTAL=20
OUTPUT=$(kubectl apply -f insecure-manifests -n baseline 2>&1)

BLOCKED=$(echo "$OUTPUT" | grep -c "Forbidden")
ALLOWED=$((TOTAL - BLOCKED))

echo "===== Experiment Result ====="
echo "Blocked: $BLOCKED"
echo "Allowed: $ALLOWED"
echo "MBR: $(echo "scale=2; $BLOCKED / $TOTAL" | bc)"
echo "Timestamp: $(date)"

echo "$OUTPUT" > experiment-$(date +%s).log

