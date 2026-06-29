#!/bin/bash

echo "===== Secrets Management Enforcement Rate Experiment ====="

TEST_DIR="k8s/secrets-tests"

TOTAL=0
PASSED=0
FAILED=0

echo

for file in "$TEST_DIR"/*.yaml
do
    TOTAL=$((TOTAL+1))

    echo "Testing: $file"

    kubectl delete -f "$file" --ignore-not-found >/dev/null 2>&1

    OUTPUT=$(kubectl apply --dry-run=server -f "$file" 2>&1)

    if [[ "$file" == *"valid-external-secret"* ]]; then

        if [[ $? -eq 0 ]]; then
            echo "Result: ALLOWED"
            PASSED=$((PASSED+1))
        else
            echo "Result: BLOCKED (Unexpected)"
            FAILED=$((FAILED+1))
        fi

    else

        if echo "$OUTPUT" | grep -qi "denied"; then
            echo "Result: BLOCKED"
            PASSED=$((PASSED+1))
        else
            echo "Result: ALLOWED (Unexpected)"
            FAILED=$((FAILED+1))
        fi

    fi

    echo "--------------------------------"

done

SMER=$(awk "BEGIN {printf \"%.2f\", $PASSED/$TOTAL}")

echo
echo "===== Experiment Result ====="
echo "Total Secret Tests: $TOTAL"
echo "Correct Decisions: $PASSED"
echo "Incorrect Decisions: $FAILED"
echo "SMER = $SMER"
echo "Timestamp: $(date)"