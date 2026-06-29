#!/bin/bash

echo "===== Runtime Response Success Rate Experiment ====="

TEST_DIR="k8s/response-tests"

TOTAL=0
SUCCESS=0
FAILED=0

echo

for file in "$TEST_DIR"/*.yaml
do

    TOTAL=$((TOTAL+1))

    POD=$(basename "$file" .yaml)

    echo "Testing: $POD"

    kubectl delete -f "$file" --ignore-not-found >/dev/null 2>&1

    kubectl apply -f "$file" >/dev/null

    sleep 40

    STATUS=$(kubectl get pod $POD -n hardened \
        --ignore-not-found \
        -o jsonpath='{.status.phase}' 2>/dev/null)

    if [[ -z "$STATUS" ]]; then

        echo "Response: SUCCESS"

        SUCCESS=$((SUCCESS+1))

    else

        echo "Response: FAILED"

        FAILED=$((FAILED+1))

    fi

    echo "--------------------------------"

done

RRSR=$(awk "BEGIN {printf \"%.2f\", $SUCCESS/$TOTAL}")

echo
echo "===== Experiment Result ====="
echo "Runtime Attacks: $TOTAL"
echo "Automatic Responses: $SUCCESS"
echo "Failed Responses: $FAILED"
echo "RRSR = $RRSR"
echo "Timestamp: $(date)"