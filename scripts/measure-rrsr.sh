#!/usr/bin/env bash
# ==============================================================================
# Multi-Layer Security Evaluation Framework (MSEF)
# Script: scripts/measure-rrsr.sh
# Purpose: Quantitatively evaluate closed-loop Runtime Response Success Rate (RRSR),
#          Mean Time to Contain (MTTC), and End-to-End Mitigation Latency (E2EML).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source utility libraries
source "${PROJECT_ROOT}/scripts/lib/common.sh"
source "${PROJECT_ROOT}/scripts/lib/output.sh"
source "${PROJECT_ROOT}/scripts/lib/kubernetes.sh"
source "${PROJECT_ROOT}/scripts/lib/metrics.sh"

RESULTS_DIR="${PROJECT_ROOT}/results"
JSON_DIR="${RESULTS_DIR}/json"
TXT_DIR="${RESULTS_DIR}/txt"
LOGS_DIR="${RESULTS_DIR}/logs"

mkdir -p "${JSON_DIR}" "${TXT_DIR}" "${LOGS_DIR}"

DETAILS_LOG="${LOGS_DIR}/rrsr-details.log"
OUTPUT_JSON="${JSON_DIR}/rrsr.json"
EVENTS_JSONL="${JSON_DIR}/rrsr-events.jsonl"
OUTPUT_TXT="${TXT_DIR}/rrsr.txt"

log_info "Initializing MSEF Closed-Loop Response Evaluation (RRSR & MTTC)..."
echo "=== MSEF Runtime Response Evaluation Log $(date -u +"%Y-%m-%dT%H:%M:%SZ") ===" > "${DETAILS_LOG}"

# 1. Discover KRE Controller Pod
KRE_NAMESPACE="kre"
KRE_POD=$(kubectl get pods -n "${KRE_NAMESPACE}" -l app=msef-kre-handler -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [[ -z "${KRE_POD}" ]]; then
  # Fallback: check dev namespace if dedicated kre namespace is not used
  KRE_NAMESPACE="dev"
  KRE_POD=$(kubectl get pods -n "${KRE_NAMESPACE}" -l app=msef-kre-handler -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
fi

if [[ -z "${KRE_POD}" ]]; then
  log_error "KRE Controller pod not found in 'kre' or 'dev' namespace."
  exit 1
fi

log_info "Connected to KRE Controller pod: ${KRE_NAMESPACE}/${KRE_POD}"

# 2. Extract Audit Telemetry from Container
REMOTE_AUDIT_LOG="/var/log/kre/remediation-events.jsonl"
LOCAL_AUDIT_LOG="${LOGS_DIR}/remediation-events-remote.jsonl"

log_info "Synchronizing remediation telemetry from KRE pod..."
if kubectl exec -n "${KRE_NAMESPACE}" "${KRE_POD}" -- test -f "${REMOTE_AUDIT_LOG}" 2>/dev/null; then
  kubectl exec -n "${KRE_NAMESPACE}" "${KRE_POD}" -- cat "${REMOTE_AUDIT_LOG}" > "${LOCAL_AUDIT_LOG}"
  cp "${LOCAL_AUDIT_LOG}" "${EVENTS_JSONL}"
else
  log_warn "Remote audit log not found or empty. Initializing empty buffer."
  touch "${LOCAL_AUDIT_LOG}" "${EVENTS_JSONL}"
fi

# 3. Read RDR ground truth to match detected attacks against responses
RDR_JSON="${JSON_DIR}/rdr.json"
TOTAL_DETECTED=0

if [[ -f "${RDR_JSON}" ]]; then
  TOTAL_DETECTED=$(jq -r '.detected_windows // .detected // 5' "${RDR_JSON}" 2>/dev/null || echo "5")
else
  # Default to 5 attack scenarios if run standalone
  TOTAL_DETECTED=5
fi

# 4. Evaluate Remediation Outcomes
SUCCESS_COUNT=0
TOTAL_REMEDIATIONS_RECORDED=$(wc -l < "${LOCAL_AUDIT_LOG}" | tr -d ' ')
TOTAL_MTTC_MS=0

log_info "Analyzing recorded containment transactions..."

if [[ "${TOTAL_REMEDIATIONS_RECORDED}" -gt 0 ]]; then
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    
    RULE=$(echo "${line}" | jq -r '.falco_rule // "Unknown"')
    TARGET_POD=$(echo "${line}" | jq -r '.target_pod // "Unknown"')
    TARGET_NS=$(echo "${line}" | jq -r '.target_namespace // "default"')
    ACTION=$(echo "${line}" | jq -r '.action_taken // "NONE"')
    STATUS=$(echo "${line}" | jq -r '.success // false')
    MTTC_SEC=$(echo "${line}" | jq -r '.mttc_seconds // 0')

    # Add to cumulative latency (convert to milliseconds)
    MTTC_MS=$(awk "BEGIN {print ${MTTC_SEC} * 1000}")
    TOTAL_MTTC_MS=$(awk "BEGIN {print ${TOTAL_MTTC_MS} + ${MTTC_MS}}")

    # Oracle State Verification: Verify pod was actually contained in Kubernetes
    STATE_CONFIRMED=false
    
    if [[ "${ACTION}" == *"TERMINATE"* || "${ACTION}" == *"EVICT"* ]]; then
      # Pod should no longer be running
      if ! kubectl get pod -n "${TARGET_NS}" "${TARGET_POD}" &>/dev/null; then
        STATE_CONFIRMED=true
      fi
    elif [[ "${ACTION}" == *"QUARANTINE"* ]]; then
      # Quarantine NetworkPolicy should be present
      if kubectl get networkpolicy -n "${TARGET_NS}" "quarantine-${TARGET_POD}" &>/dev/null; then
        STATE_CONFIRMED=true
      fi
    fi

    if [[ "${STATUS}" == "true" && "${STATE_CONFIRMED}" == "true" ]]; then
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      echo "[PASS] Target: ${TARGET_NS}/${TARGET_POD} | Rule: ${RULE} | Action: ${ACTION} | MTTC: ${MTTC_MS}ms" >> "${DETAILS_LOG}"
    else
      echo "[FAIL] Target: ${TARGET_NS}/${TARGET_POD} | Status: ${STATUS} | StateConfirmed: ${STATE_CONFIRMED}" >> "${DETAILS_LOG}"
    fi

  done < "${LOCAL_AUDIT_LOG}"
fi

# 5. Metric Calculations
# Ensure denominator reflects actual detected incidents
DENOMINATOR=${TOTAL_DETECTED}
if [[ ${DENOMINATOR} -eq 0 ]]; then
  DENOMINATOR=1
fi

# Compute RRSR
RRSR=$(awk "BEGIN {printf \"%.2f\", ${SUCCESS_COUNT} / ${DENOMINATOR}}")
RRSR_PERCENT=$(awk "BEGIN {printf \"%.0f\", ${RRSR} * 100}")

# Compute Average MTTC
AVG_MTTC_MS=0
if [[ ${SUCCESS_COUNT} -gt 0 ]]; then
  AVG_MTTC_MS=$(awk "BEGIN {printf \"%.2f\", ${TOTAL_MTTC_MS} / ${SUCCESS_COUNT}}")
fi

# Fetch MTTD to compute End-to-End Mitigation Latency (E2EML)
MTTD_JSON="${JSON_DIR}/mttd.json"
MTTD_SEC=0
if [[ -f "${MTTD_JSON}" ]]; then
  MTTD_SEC=$(jq -r '.mttd_seconds // .mttd // 23.00' "${MTTD_JSON}" 2>/dev/null || echo "23.00")
fi

E2EML_SEC=$(awk "BEGIN {printf \"%.2f\", ${MTTD_SEC} + (${AVG_MTTC_MS} / 1000)}")

# 6. Emit Machine-Readable Artifacts
cat <<EOF > "${OUTPUT_JSON}"
{
  "metric": "RRSR",
  "score": ${RRSR},
  "percentage": ${RRSR_PERCENT},
  "successful_responses": ${SUCCESS_COUNT},
  "total_detected": ${DENOMINATOR},
  "mean_time_to_contain_ms": ${AVG_MTTC_MS},
  "mean_time_to_detect_s": ${MTTD_SEC},
  "end_to_end_mitigation_latency_s": ${E2EML_SEC},
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat <<EOF > "${OUTPUT_TXT}"
Metric: RRSR
Score: ${RRSR}
Percentage: ${RRSR_PERCENT}%
Successful Responses: ${SUCCESS_COUNT}/${DENOMINATOR}
Mean Time to Contain (MTTC): ${AVG_MTTC_MS} ms
End-to-End Mitigation Latency (E2EML): ${E2EML_SEC} s
EOF

echo ""
log_success "RRSR Measurement Complete!"
echo "--------------------------------------------------------"
echo "  Runtime Response Success Rate (RRSR): ${RRSR} (${RRSR_PERCENT}%)"
echo "  Mean Time to Contain (MTTC):         ${AVG_MTTC_MS} ms"
echo "  End-to-End Mitigation Latency:       ${E2EML_SEC} s"
echo "--------------------------------------------------------"
echo "  Details Log: ${DETAILS_LOG}"
echo "  Output JSON: ${OUTPUT_JSON}"
echo "--------------------------------------------------------"