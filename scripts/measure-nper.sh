#!/bin/bash

echo "===== Network Policy Enforcement Rate Experiment ====="

TEST_DIR="k8s/network-tests"

TOTAL=0
PASSED=0
FAILED=0

echo

for file in "$TEST_DIR"/*.yaml
do

    TOTAL=$((TOTAL+1))

    echo "Testing: $file"

    kubectl delete -f "$file" --ignore-not-found >/dev/null 2>&1

    kubectl apply -f "$file" >/dev/null

    POD=$(basename "$file" .yaml)

    kubectl wait \
      --for=condition=Ready pod/$POD \
      -n hardened \
      --timeout=60s >/dev/null 2>&1

    sleep 10

    LOGS=$(kubectl logs $POD -n hardened 2>/dev/null)

    if [[ "$file" == *allowed* ]]; then

        if echo "$LOGS" | grep -qi success; then
            echo "Result: ALLOWED"
            PASSED=$((PASSED+1))
        else
            echo "Result: BLOCKED (Unexpected)"
            FAILED=$((FAILED+1))
        fi

    else

        if echo "$LOGS" | grep -qi denied; then
            echo "Result: BLOCKED"
            PASSED=$((PASSED+1))
        else
            echo "Result: ALLOWED (Unexpected)"
            FAILED=$((FAILED+1))
        fi

    fi

    kubectl delete pod $POD -n hardened --ignore-not-found >/dev/null

    echo "--------------------------------"

done

NPER=$(awk "BEGIN {printf \"%.2f\", $PASSED/$TOTAL}")

echo
echo "===== Experiment Result ====="
echo "Total Network Tests: $TOTAL"
echo "Correct Decisions: $PASSED"
echo "Incorrect Decisions: $FAILED"
echo "NPER = $NPER"
echo "Timestamp: $(date)"