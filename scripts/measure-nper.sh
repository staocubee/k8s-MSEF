#!/usr/bin/env bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Network Policy Enforcement Rate (NPER)
#
###############################################################################

set -euo pipefail

source scripts/lib/common.sh
source scripts/lib/kubernetes.sh
source scripts/lib/metrics.sh
source scripts/lib/output.sh

init_framework
print_banner "Network Policy Enforcement Rate (NPER)"

TEST_FILE="${TEST_FILE:-k8s/network-test/network-policy-tests.yaml}"

TOTAL=4
PASSED=0
FAILED=0

DETAILS="$LOG_DIR/nper-details.log"
: > "$DETAILS"

###############################################################################
# Deploy test environment
###############################################################################

if [ -d "$TEST_FILE" ]; then
    kubectl apply -f "$TEST_FILE/"
else
    kubectl apply -f "$TEST_FILE"
fi

kubectl wait \
    --for=condition=Ready \
    pod/test-allow-internet \
    -n connectivity-tests \
    --timeout=120s

kubectl wait \
    --for=condition=Ready \
    pod/test-deny-internet \
    -n connectivity-tests \
    --timeout=120s

kubectl wait \
    --for=condition=Ready \
    pod/isolated-app \
    -n isolated-target \
    --timeout=120s

# Give CNI 3 seconds to ensure eBPF/iptables rules are synchronized
sleep 3

###############################################################################
# Helper
###############################################################################

run_test() {

    local description="$1"
    local command="$2"
    local expected="$3"

    if eval "$command" >/dev/null 2>&1
    then
        actual="ALLOW"
    else
        actual="BLOCK"
    fi

    if [[ "$actual" == "$expected" ]]
    then
        PASSED=$((PASSED+1))
        result="PASS"
    else
        FAILED=$((FAILED+1))
        result="FAIL"
    fi

    cat >> "$DETAILS" <<EOF
Test: $description
Expected: $expected
Actual: $actual
Result: $result
----------------------------------------
EOF

}
###############################################################################
# Test 1: DNS resolution should work
###############################################################################
run_test \
"DNS Resolution" \
"kubectl exec -n connectivity-tests test-allow-internet -- curl -s --connect-timeout 5 -o /dev/null -w '%{http_code}' https://example.com" \
"ALLOW"

###############################################################################
# Test 2: Internet should work
###############################################################################
run_test \
"Internet Access" \
"kubectl exec -n connectivity-tests test-allow-internet -- curl -s -I --connect-timeout 5 --max-time 10 https://example.com" \
"ALLOW"

###############################################################################
# Test 3: Internet should be blocked
###############################################################################
run_test \
"Internet Deny" \
"kubectl exec -n connectivity-tests test-deny-internet -- curl -s -I --connect-timeout 5 --max-time 10 https://example.com" \
"BLOCK"

###############################################################################
# Test 4: Cross namespace should be blocked
###############################################################################
run_test \
"Cross Namespace Access" \
"kubectl exec -n connectivity-tests test-allow-internet -- curl -s -I --connect-timeout 5 --max-time 10 http://isolated-service.isolated-target.svc.cluster.local" \
"BLOCK"
###############################################################################
# Cleanup
###############################################################################

kubectl delete -f "$TEST_FILE" --ignore-not-found

###############################################################################

NPER=$(score "$PASSED" "$TOTAL")

cat > "$JSON_DIR/nper.json" <<EOF
{
  "metric":"NPER",
  "total_tests":$TOTAL,
  "correct_decisions":$PASSED,
  "incorrect_decisions":$FAILED,
  "score":$NPER
}
EOF

cat "$JSON_DIR/nper.json"