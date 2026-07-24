#!/usr/bin/env bash

###############################################################################
#
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Metric:
#
# Runtime Response Success Rate (RRSR)
#
# RRSR = Successful Automated Responses / Runtime Attacks
#
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"

###############################################################################
# Configuration
###############################################################################

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="$RESULTS_DIR/json"
TXT_DIR="$RESULTS_DIR/txt"
LOG_DIR="$RESULTS_DIR/logs"

mkdir -p "$JSON_DIR" "$TXT_DIR" "$LOG_DIR"

DETAILS="$LOG_DIR/rrsr-details.log"

: > "$DETAILS"

###############################################################################
# KRE metrics file
###############################################################################

METRICS_FILE="${METRICS_FILE:-/tmp/rrsr-events.jsonl}"

###############################################################################

banner "Runtime Response Success Rate (RRSR)"

###############################################################################

if [[ ! -f "$METRICS_FILE" ]]; then

    echo "ERROR:"

    echo "$METRICS_FILE not found."

    echo

    echo "Run runtime attack simulation first."

    exit 1

fi

###############################################################################

TOTAL=$(wc -l < "$METRICS_FILE")

SUCCESS=0

FAILED=0

TOTAL_LATENCY=0

###############################################################################

while read -r EVENT
do

    RULE=$(echo "$EVENT" | jq -r '.rule')

    POD=$(echo "$EVENT" | jq -r '.pod')

    NS=$(echo "$EVENT" | jq -r '.namespace')

    OK=$(echo "$EVENT" | jq -r '.success')

    LATENCY=$(echo "$EVENT" | jq -r '.latency')

    TOTAL_LATENCY=$(awk \
        -v a="$TOTAL_LATENCY" \
        -v b="$LATENCY" \
        'BEGIN{print a+b}')

    if [[ "$OK" == "true" ]]; then

        RESULT="SUCCESS"

        SUCCESS=$((SUCCESS+1))

    else

        RESULT="FAILED"

        FAILED=$((FAILED+1))

    fi

cat >> "$DETAILS" <<EOF
Rule      : $RULE
Namespace : $NS
Pod       : $POD
Latency   : ${LATENCY}s
Result    : $RESULT
----------------------------------------
EOF

done < "$METRICS_FILE"

###############################################################################

RRSR=$(awk \
    -v s="$SUCCESS" \
    -v t="$TOTAL" \
'BEGIN{
    if(t==0){print "0.00"; exit}
    printf "%.2f",s/t
}')

###############################################################################

AVG_LATENCY=$(awk \
    -v l="$TOTAL_LATENCY" \
    -v t="$TOTAL" \
'BEGIN{
    if(t==0){print "0.00"; exit}
    printf "%.2f",l/t
}')

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/rrsr.json" <<EOF
{
  "metric":"RRSR",
  "runtime_attacks":$TOTAL,
  "successful_responses":$SUCCESS,
  "failed_responses":$FAILED,
  "average_latency_seconds":$AVG_LATENCY,
  "score":$RRSR
}
EOF

###############################################################################
# TXT
###############################################################################

cat > "$TXT_DIR/rrsr.txt" <<EOF
==========================================
Runtime Response Success Rate
==========================================

Runtime Attacks

$TOTAL

Successful Responses

$SUCCESS

Failed Responses

$FAILED

Average Remediation Latency

${AVG_LATENCY} seconds

------------------------------------------

RRSR

$RRSR

Generated

$(date)

EOF

###############################################################################

cat "$TXT_DIR/rrsr.txt"