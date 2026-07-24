#!/usr/bin/env bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Metric:
# Network Policy Enforcement Rate (NPER)
#
# NPER = Correct Network Policy Decisions / Total Tests
###############################################################################

set -euo pipefail

source scripts/lib/common.sh
source scripts/lib/kubernetes.sh
source scripts/lib/validation.sh
source scripts/lib/metrics.sh
source scripts/lib/output.sh

init_framework

print_banner "Network Policy Enforcement Rate (NPER)"

TEST_DIR="${TEST_DIR:-k8s/network-test}"
TARGET_NS="${TARGET_NS:-hardened}"

require_namespace "$TARGET_NS"

TOTAL=0
PASSED=0
FAILED=0

DETAILS="$LOG_DIR/nper-details.log"
: > "$DETAILS"

###############################################################################
# Helper
###############################################################################

run_test() {

    local manifest="$1"
    local pod="$2"
    local expected="$3"
    local command="$4"

    delete_manifest "$manifest" "$TARGET_NS"

    apply_manifest "$manifest" "$TARGET_NS" >/dev/null

    wait_for_pod "$pod" "$TARGET_NS" 90s

    if pod_exec "$pod" "$TARGET_NS" sh -c "$command" >/dev/null 2>&1
    then
        actual="ALLOW"
    else
        actual="BLOCK"
    fi

    if [[ "$actual" == "$expected" ]]
    then
        RESULT="PASS"
        PASSED=$((PASSED+1))
    else
        RESULT="FAIL"
        FAILED=$((FAILED+1))
    fi

    printf "%s : %s\n" "$(basename "$manifest")" "$RESULT" >> "$DETAILS"

    delete_manifest "$manifest" "$TARGET_NS"
}

###############################################################################
# Execute tests
###############################################################################

for FILE in "$TEST_DIR"/*.yaml
do

    TOTAL=$((TOTAL+1))

    NAME=$(basename "$FILE")

    POD="${NAME%.yaml}"

    log_info "Testing $NAME"

    case "$NAME" in

        allow-dns.yaml)

            run_test \
                "$FILE" \
                "$POD" \
                "ALLOW" \
                "nslookup kubernetes.default.svc.cluster.local"

            ;;

        allow-api.yaml)

            run_test \
                "$FILE" \
                "$POD" \
                "ALLOW" \
                "wget --spider --timeout=5 https://kubernetes.default.svc"

            ;;

        deny-external.yaml)

            run_test \
                "$FILE" \
                "$POD" \
                "BLOCK" \
                "wget --spider --timeout=5 https://google.com"

            ;;

        deny-cross-namespace.yaml)

            run_test \
                "$FILE" \
                "$POD" \
                "BLOCK" \
                "wget --spider --timeout=5 http://nginx.baseline.svc.cluster.local"

            ;;

        *)

            log_warn "Skipping unknown test $NAME"

            TOTAL=$((TOTAL-1))

            ;;

    esac

done

###############################################################################

NPER=$(score "$PASSED" "$TOTAL")

cat > "$JSON_DIR/nper.json" <<EOF
{
  "framework":"Kubernetes MSEF",
  "metric":"NPER",
  "timestamp":"$(timestamp)",
  "total":$TOTAL,
  "correct_decisions":$PASSED,
  "incorrect_decisions":$FAILED,
  "score":$NPER
}
EOF

cat > "$TXT_DIR/nper.txt" <<EOF
==========================================
Network Policy Enforcement Rate
==========================================

Total Tests         : $TOTAL
Correct Decisions   : $PASSED
Incorrect Decisions : $FAILED

NPER                : $NPER

Generated : $(timestamp)

EOF

cat "$JSON_DIR/nper.json"