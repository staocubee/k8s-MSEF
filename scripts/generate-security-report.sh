#!/bin/bash
set -euo pipefail

RESULTS_DIR="${RESULTS_DIR:-results}"

get_metric() {
  local metric="$1"
  local file="$2"

  if [ -f "$file" ]; then
    grep -E "^$metric[[:space:]]*=" "$file" | tail -n 1 | awk -F'= ' '{print $2}' || true
  fi
}

MBR=$(get_metric "MBR" "$RESULTS_DIR/mbr-result.txt")
SPR=$(get_metric "SPR" "$RESULTS_DIR/spr-result.txt")
RDR=$(get_metric "RDR" "$RESULTS_DIR/rdr-result.txt")
MTTD=$(get_metric "MTTD" "$RESULTS_DIR/mttd-result.txt")
FPR=$(get_metric "FPR" "$RESULTS_DIR/fpr-result.txt")

echo ""
echo "================================"
echo "Kubernetes Security Evaluation Report"
echo "================================"

echo ""
echo "Final Metrics"
echo "-------------"
echo "MBR = ${MBR:-N/A}"
echo "SPR = ${SPR:-N/A}"
echo "RDR = ${RDR:-N/A}"
echo "MTTD = ${MTTD:-N/A}"
echo "FPR = ${FPR:-N/A}"
echo ""

echo "--------------------------------"
echo "Interpretation"
echo "--------------------------------"
echo "Admission Control Strength : ${MBR:-N/A}"
echo "Signature Integrity Enforcement : ${SPR:-N/A}"
echo "Runtime Detection Coverage : ${RDR:-N/A}"
echo "Runtime Detection Speed : ${MTTD:-N/A}"
echo "Detection Noise / False Positive Rate : ${FPR:-N/A}"
echo ""

echo "Report generated at: $(date)"