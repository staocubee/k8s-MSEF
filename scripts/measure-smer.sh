#!/usr/bin/env bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Metric:
# Secrets Management Enforcement Rate (SMER)
#
# SMER = Correct Secret Enforcement Decisions / Total Tests
###############################################################################

set -euo pipefail

source scripts/lib/common.sh
source scripts/lib/kubernetes.sh
source scripts/lib/validation.sh
source scripts/lib/metrics.sh
source scripts/lib/output.sh

init_framework

print_banner "Secrets Management Enforcement Rate (SMER)"

TEST_DIR="${TEST_DIR:-k8s/secrets-test}"
TARGET_NS="${TARGET_NS:-hardened}"

require_namespace "$TARGET_NS"

# Either Gatekeeper or Kyverno policies should exist
require_policy_engine

TOTAL=0
PASSED=0
FAILED=0

DETAILS="$LOG_DIR/smer-details.log"
: > "$DETAILS"

###############################################################################
# Execute tests
###############################################################################

for FILE in "$TEST_DIR"/*.yaml
do

    TOTAL=$((TOTAL+1))

    NAME=$(basename "$FILE")

    log_info "Testing $NAME"

    OUTPUT=$(apply_dry_run "$FILE" "$TARGET_NS" || true)

    ###########################################################
    # Expected result
    ###########################################################

    case "$NAME" in

        valid-external-secret.yaml)

            EXPECTED="ALLOW"
            ;;

        *)

            EXPECTED="BLOCK"
            ;;

    esac

    ###########################################################
    # Actual result
    ###########################################################

    if admission_blocked "$OUTPUT"
    then
        ACTUAL="BLOCK"
    else
        ACTUAL="ALLOW"
    fi

    ###########################################################
    # Score
    ###########################################################

    if [[ "$EXPECTED" == "$ACTUAL" ]]
    then
        RESULT="PASS"
        PASSED=$((PASSED+1))
    else
        RESULT="FAIL"
        FAILED=$((FAILED+1))
    fi

    cat >> "$DETAILS" <<EOF
Test: $NAME
Expected: $EXPECTED
Actual: $ACTUAL
Result: $RESULT
----------------------------------------
EOF

done

###############################################################################

SMER=$(score "$PASSED" "$TOTAL")

cat > "$JSON_DIR/smer.json" <<EOF
{
  "framework":"Kubernetes MSEF",
  "metric":"SMER",
  "timestamp":"$(timestamp)",
  "total_tests":$TOTAL,
  "correct_decisions":$PASSED,
  "incorrect_decisions":$FAILED,
  "score":$SMER
}
EOF

cat > "$TXT_DIR/smer.txt" <<EOF
==========================================
Secrets Management Enforcement Rate
==========================================

Total Tests         : $TOTAL
Correct Decisions   : $PASSED
Incorrect Decisions : $FAILED

SMER                : $SMER

Generated : $(timestamp)

EOF

cat "$JSON_DIR/smer.json"