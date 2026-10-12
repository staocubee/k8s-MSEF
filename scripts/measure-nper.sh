#!/usr/bin/env bash

set -euo pipefail

source scripts/lib/common.sh
source scripts/lib/output.sh
source scripts/lib/metrics.sh

init_framework
print_banner "Network Policy Enforcement Rate (NPER)"

ENV_FILE="${PROJECT_ROOT}/k8s/network-test/network-environment.yaml"

JSON_FILE="$JSON_DIR/nper.json"
TXT_FILE="$TXT_DIR/nper.txt"
DETAILS="$LOG_DIR/nper-details.log"

: > "$DETAILS"

PASS=0
FAIL=0

echo "Deploying network test environment..."
kubectl apply -f "$ENV_FILE"

echo "Waiting for test pods..."
kubectl wait \
    --for=condition=Ready \
    pod/test-allow-internet \
    -n connectivity-tests \
    --timeout=120s

kubectl wait \
    --for=condition=Ready \
    pod/test-default-deny \
    -n connectivity-tests \
    --timeout=120s

kubectl wait \
    --for=condition=Ready \
    pod/isolated-app \
    -n isolated-target \
    --timeout=120s

###############################################################################

run_test () {

    local name="$1"
    local expected="$2"
    shift 2

    if "$@" >/dev/null 2>&1
    then
        actual="ALLOW"
    else
        actual="BLOCK"
    fi

    if [[ "$actual" == "$expected" ]]
    then
        result="PASS"
        PASS=$((PASS+1))
    else
        result="FAIL"
        FAIL=$((FAIL+1))
    fi

    cat >> "$DETAILS" <<EOF
Test: $name
Expected: $expected
Actual: $actual
Result: $result
----------------------------------------
EOF
}

###############################################################################
# NPER DNS ALLOW
###############################################################################

run_test \
"NPER DNS Resolution" \
"ALLOW" \
kubectl exec -n connectivity-tests test-allow-internet -- \
nslookup kubernetes.default.svc.cluster.local

###############################################################################
# IER DNS BLOCK
###############################################################################

run_test \
"IER DNS Resolution" \
"BLOCK" \
kubectl exec -n connectivity-tests test-default-deny -- \
nslookup kubernetes.default.svc.cluster.local

###############################################################################
# NPER Internet allowed
###############################################################################

run_test \
"NPER Internet Allowed" \
"ALLOW" \
kubectl exec -n connectivity-tests test-allow-internet -- \
curl -s --connect-timeout 5 https://example.com

###############################################################################
# IER Internet blocked
###############################################################################

run_test \
"IER Internet Blocked" \
"BLOCK" \
kubectl exec -n connectivity-tests test-default-deny -- \
curl -s --connect-timeout 5 https://216.58.214.14

###############################################################################
# NPERCross namespace Allowed
###############################################################################
run_test \
"NPER Cross Namespace" \
"ALLOW" \
kubectl exec -n connectivity-tests test-crossns -- \
curl -s --connect-timeout 5 \
http://isolated-service.isolated-target.svc.cluster.local

###############################################################################
# IER Cross namespace blocked
###############################################################################
run_test \
"IER Cross Namespace" \
"BLOCK" \
kubectl exec -n connectivity-tests test-default-deny -- \
curl -s --connect-timeout 5 \
http://isolated-service.isolated-target.svc.cluster.local


###############################################################################

TOTAL=$((PASS+FAIL))

NPER=$(score "$PASS" "$TOTAL")

cat > "$JSON_FILE" <<EOF
{
  "metric":"NPER",
  "total_tests":$TOTAL,
  "correct_decisions":$PASS,
  "incorrect_decisions":$FAIL,
  "score":$NPER
}
EOF

cat "$JSON_FILE"

echo
echo "Cleaning up..."
kubectl delete -f "$ENV_FILE" --ignore-not-found=true