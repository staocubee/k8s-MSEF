#!/usr/bin/env bash

###############################################################################
# Secrets Management Enforcement Rate (SMER)
###############################################################################

set -euo pipefail

source scripts/lib/common.sh
source scripts/lib/kubernetes.sh
source scripts/lib/output.sh
source scripts/lib/metrics.sh

init_framework
print_banner "Secrets Management Enforcement Rate (SMER)"

TEST_DIR="${TEST_DIR:-k8s/secrets-test}"
TARGET_NS="${TARGET_NS:-hardened}"

TOTAL=0
PASSED=0
FAILED=0

DETAILS="$LOG_DIR/smer-details.log"
: > "$DETAILS"

###############################################################################

for FILE in "$TEST_DIR"/*.yaml
do

    NAME=$(basename "$FILE")
    [[ "$NAME" == "kustomization.yaml" ]] && continue

    TOTAL=$((TOTAL+1))

    OUTPUT=$(kubectl apply \
        --dry-run=server \
        -n "$TARGET_NS" \
        -f "$FILE" \
        2>&1 || true)

    ##########################################################
    # Expected
    ##########################################################

    case "$NAME" in

        valid-external-secret.yaml|external-secret-with-clustersecretstore.yaml|sealed-secret.yaml)

            EXPECTED="ALLOW"

            ;;

        *)

            EXPECTED="BLOCK"

            ;;

    esac

    ##########################################################

    if echo "$OUTPUT" | grep -Ei \
        "denied|forbidden|violation|failed|error" >/dev/null
    then
        ACTUAL="BLOCK"
    else
        ACTUAL="ALLOW"
    fi

    ##########################################################

    if [[ "$EXPECTED" == "$ACTUAL" ]]
    then
        PASSED=$((PASSED+1))
        RESULT="PASS"
    else
        FAILED=$((FAILED+1))
        RESULT="FAIL"
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
  "metric":"SMER",
  "total_tests":$TOTAL,
  "correct_decisions":$PASSED,
  "incorrect_decisions":$FAILED,
  "score":$SMER
}
EOF

cat "$JSON_DIR/smer.json"