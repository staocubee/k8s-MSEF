#!/bin/bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Metric:
# Runtime Detection Rate (RDR)
#
# RDR = Detected Runtime Attacks / Simulated Runtime Attacks
#
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

###############################################################################
# Configuration
###############################################################################

FALCO_NS="${FALCO_NS:-falco}"

TARGET_NS="${TARGET_NS:-baseline}"

TARGET_POD="${TARGET_POD:-insecure-write-root}"

ATTACKER_POD="${ATTACKER_POD:-runtime-attacker}"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="${RESULTS_DIR}/json"

TXT_DIR="${RESULTS_DIR}/txt"

LOG_DIR="${RESULTS_DIR}/logs"

mkdir -p "$JSON_DIR" "$TXT_DIR" "$LOG_DIR"

DETAILS="$LOG_DIR/rdr-details.log"

> "$DETAILS"

###############################################################################

echo "=========================================="

echo "Runtime Detection Rate (RDR)"

echo "=========================================="

###############################################################################
# Locate Falco
###############################################################################

FALCO_PODS=$(kubectl get pods -n "$FALCO_NS" \
-l app.kubernetes.io/name=falco \
-o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null || true)

if [ -z "$FALCO_PODS" ]; then

    FALCO_PODS=$(kubectl get pods -n "$FALCO_NS" \
    -l app=falco \
    -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null || true)

fi

if [ -z "$FALCO_PODS" ]; then

    echo "No Falco pods found."

    exit 1

fi

###############################################################################

SIMULATED=5

DETECTED=0

###############################################################################

run_attack() {

NAME="$1"

POD="$2"

COMMAND="$3"

PATTERN="$4"

echo "Running: $NAME"

START=$(date +%s)

kubectl exec -n "$TARGET_NS" "$POD" -- sh -c "$COMMAND" >/dev/null 2>&1 || true

sleep 15

LOGS=""

for FP in $FALCO_PODS
do

LOGS="${LOGS}
$(kubectl logs -n "$FALCO_NS" "$FP" --since=60s 2>/dev/null)"

done

FOUND=0

if echo "$LOGS" | grep -Eiq "$POD|$PATTERN"
then

FOUND=1

DETECTED=$((DETECTED+1))

echo "Detected"

else

echo "Not Detected"

fi

END=$(date +%s)

ELAPSED=$((END-START))

echo "$ELAPSED" >> "$RESULTS_DIR/mttd-values.txt"

cat >> "$DETAILS" <<EOF
Attack: $NAME
Pod: $POD
Detected: $FOUND
Detection Time: ${ELAPSED}s
----------------------------------------
EOF

}

###############################################################################

run_attack "Sensitive File Access" "$TARGET_POD" "cat /etc/shadow" "shadow|etc/shadow"

run_attack "Write Root Filesystem" "$TARGET_POD" "touch /root/hacked" "root filesystem|/root/hacked"

run_attack "Privilege Escalation" "$TARGET_POD" "chmod +s /bin/sh" "setuid|chmod"

run_attack "Outbound TCP" "$TARGET_POD" "echo hi >/dev/tcp/example.com/80" "connection|network"

run_attack "Outbound Curl" "$ATTACKER_POD" "curl -s http://example.com >/dev/null" "curl|connection"

###############################################################################

RDR=$(awk -v d="$DETECTED" -v t="$SIMULATED" 'BEGIN{printf "%.2f",d/t}')

###############################################################################
# JSON
###############################################################################

cat > "$JSON_DIR/rdr.json" <<EOF
{
    "metric":"RDR",
    "simulated_attacks":$SIMULATED,
    "detected":$DETECTED,
    "score":$RDR
}
EOF

###############################################################################
# TXT
###############################################################################

cat > "$TXT_DIR/rdr.txt" <<EOF
==========================================
Runtime Detection Rate
==========================================

Simulated Attacks : $SIMULATED
Detected          : $DETECTED

RDR               : $RDR

Generated : $(date)

EOF

cat "$JSON_DIR/rdr.json"