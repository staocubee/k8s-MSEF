#!/usr/bin/env bash
# =============================================================================
# MSEF runtime evaluation harness (Layer 4).
#
# For each scenario in k8s/runtime-tests/scenarios.tsv and each repetition:
#   1. re-apply the dedicated attack identity (msef-attack-sa + RoleBinding)
#   2. deploy the attack pod and stream its logs with timestamps, capturing the
#      MSEF_ATTACK_START line (attack time, used for MTTD)
#   3. observe for OBSERVE_SEC, then record the end state: pod present?,
#      quarantine NetworkPolicy present?, attack RoleBinding present?
#   4. clean up (pod, quarantine policies)
# Then an optional benign phase deploys each k8s/benign workload alone for
# BENIGN_SEC; any MSEF alert raised during a benign window is a false positive.
# Finally it collects all Falco logs and the KRE audit log for the run.
#
# The harness never deletes an attack pod before the observation window ends,
# so pod absence at the end of the window is attributable to KRE.
#
# It only touches: namespace "hardened" objects it created, and
# NetworkPolicies labelled msef.security/quarantine=true.
#
# Usage: scripts/run-runtime-suite.sh [--repeats N] [--observe SEC]
#        [--benign-sec SEC] [--no-benign] [--config-label C5]
# Metrics: python3 scripts/compute_runtime_metrics.py results/runs/<run_id>
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPEATS=1; OBSERVE_SEC=60; BENIGN_SEC=120; RUN_BENIGN=1; CONFIG_LABEL="unlabelled"
NS=hardened; FALCO_NS=falco; KRE_DEPLOY=msef-kre-handler
while [[ $# -gt 0 ]]; do case "$1" in
  --repeats) REPEATS="$2"; shift 2;; --observe) OBSERVE_SEC="$2"; shift 2;;
  --benign-sec) BENIGN_SEC="$2"; shift 2;; --no-benign) RUN_BENIGN=0; shift;;
  --config-label) CONFIG_LABEL="$2"; shift 2;; *) echo "unknown arg $1" >&2; exit 2;; esac; done

for c in kubectl jq python3; do command -v "$c" >/dev/null || { echo "missing $c" >&2; exit 1; }; done
kubectl get ns "$NS" >/dev/null

RUN_ID="runtime-$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$ROOT/results/runs/$RUN_ID"; mkdir -p "$RUN_DIR/scenarios" "$RUN_DIR/benign"
RUN_START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq -n --arg run_id "$RUN_ID" --arg start "$RUN_START" --arg cfg "$CONFIG_LABEL" \
  --arg commit "$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)" \
  --arg dirty "$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')" \
  --arg ctx "$(kubectl config current-context)" \
  --arg server_version "$(kubectl version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion')" \
  --arg falco_image "$(kubectl get ds -n $FALCO_NS -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' 2>/dev/null)" \
  --arg kre_image "$(kubectl get deploy -n $NS $KRE_DEPLOY -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)" \
  --arg kre_mode "$(kubectl get deploy -n $NS $KRE_DEPLOY -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="KRE_MODE")].value}' 2>/dev/null)" \
  --argjson repeats "$REPEATS" --argjson observe "$OBSERVE_SEC" --argjson benign_sec "$BENIGN_SEC" \
  '{run_id:$run_id, started:$start, config_label:$cfg, git_commit:$commit, uncommitted_files:($dirty|tonumber),
    kube_context:$ctx, server_version:$server_version, falco_image:$falco_image, kre_image:$kre_image,
    kre_mode:$kre_mode, repeats:$repeats, observe_seconds:$observe, benign_seconds:$benign_sec}' > "$RUN_DIR/run.json"
cp "$ROOT/k8s/runtime-tests/scenarios.tsv" "$RUN_DIR/"
echo "[*] run $RUN_ID -> $RUN_DIR"

cleanup_quarantine() { kubectl delete networkpolicy -n "$NS" -l msef.security/quarantine=true --ignore-not-found >/dev/null 2>&1 || true; }

while IFS=$'\t' read -r SCEN MANIFEST POD RULE ACTION MITRE <&3; do
  for REP in $(seq 1 "$REPEATS"); do
    OUT="$RUN_DIR/scenarios/${SCEN}__rep${REP}"; mkdir -p "$OUT"
    MF="$ROOT/k8s/runtime-tests/$MANIFEST"
    if [[ ! -f "$MF" ]]; then
      jq -n --arg s "$SCEN" --argjson r "$REP" '{scenario:$s, rep:$r, error:"manifest_missing"}' > "$OUT/state.json"; continue
    fi
    kubectl delete pod -n "$NS" "$POD" --ignore-not-found --wait=true >/dev/null 2>&1 || true
    cleanup_quarantine
    kubectl apply -f "$ROOT/k8s/runtime-tests/_attack-identity.yaml" >/dev/null
    T_APPLY="$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)"
    APPLY_OUT="$(kubectl apply -f "$MF" 2>&1)" || APPLY_FAILED=1
    if [[ "${APPLY_FAILED:-0}" == 1 ]]; then
      unset APPLY_FAILED
      jq -n --arg s "$SCEN" --argjson r "$REP" --arg t "$T_APPLY" --arg e "$APPLY_OUT" \
        '{scenario:$s, rep:$r, t_apply:$t, error:"apply_failed", apply_output:$e}' > "$OUT/state.json"; continue
    fi
    # Attach a timestamped log stream as soon as the container runs.
    for _ in $(seq 1 60); do
      PH="$(kubectl get pod -n "$NS" "$POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
      [[ "$PH" == Running || "$PH" == Succeeded || "$PH" == Failed ]] && break; sleep 0.5
    done
    ( kubectl logs -f --timestamps -n "$NS" "$POD" > "$OUT/pod.log" 2>&1 < /dev/null || true ) &
    LOGPID=$!
    sleep "$OBSERVE_SEC"
    UID_NOW="$(kubectl get pod -n "$NS" "$POD" -o jsonpath='{.metadata.uid}' 2>/dev/null || true)"
    PHASE_END="$(kubectl get pod -n "$NS" "$POD" -o jsonpath='{.status.phase}' 2>/dev/null || echo absent)"
    NETPOLS="$(kubectl get networkpolicy -n "$NS" -l msef.security/quarantine=true -o json | jq '[.items[].metadata.name]')"
    RB_PRESENT=true; kubectl get rolebinding -n "$NS" msef-attack-sa-probe >/dev/null 2>&1 || RB_PRESENT=false
    T_END="$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)"
    kill "$LOGPID" 2>/dev/null || true; wait "$LOGPID" 2>/dev/null || true
    jq -n --arg s "$SCEN" --argjson r "$REP" --arg pod "$POD" --arg rule "$RULE" --arg action "$ACTION" \
      --arg t_apply "$T_APPLY" --arg t_end "$T_END" --arg phase "$PHASE_END" --arg uid "$UID_NOW" \
      --argjson netpols "$NETPOLS" --argjson rb "$RB_PRESENT" \
      '{scenario:$s, rep:$r, pod:$pod, expected_rule:$rule, expected_action:$action, t_apply:$t_apply,
        t_observe_end:$t_end, pod_phase_at_end:$phase, pod_uid_at_end:$uid,
        quarantine_policies_at_end:$netpols, attack_rolebinding_present_at_end:$rb}' > "$OUT/state.json"
    kubectl delete pod -n "$NS" "$POD" --ignore-not-found --wait=false >/dev/null 2>&1 || true
    cleanup_quarantine
    echo "[*] $SCEN rep $REP: phase_at_end=$PHASE_END"
  done
done 3< <(tail -n +2 "$ROOT/k8s/runtime-tests/scenarios.tsv")

if [[ "$RUN_BENIGN" == 1 ]]; then
  for BF in "$ROOT"/k8s/benign/*.yaml; do
    B="$(basename "$BF" .yaml)"; T0="$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)"
    kubectl apply -f "$BF" > "$RUN_DIR/benign/$B.apply.log" 2>&1 || true
    sleep "$BENIGN_SEC"
    T1="$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)"
    kubectl delete -f "$BF" --ignore-not-found --wait=true >/dev/null 2>&1 || true
    jq -n --arg w "$B" --arg t0 "$T0" --arg t1 "$T1" '{window:$w, t_start:$t0, t_end:$t1}' > "$RUN_DIR/benign/$B.json"
    echo "[*] benign window $B done"
  done
fi

# Collect Falco logs from every Falco pod (no tail limit) and the KRE audit log.
mkdir -p "$RUN_DIR/falco"
for FP in $(kubectl get pods -n "$FALCO_NS" -l app.kubernetes.io/name=falco -o jsonpath='{.items[*].metadata.name}'); do
  kubectl logs -n "$FALCO_NS" "$FP" -c falco --since-time="$RUN_START" > "$RUN_DIR/falco/$FP.log" 2>&1 || true
done
kubectl exec -n "$NS" "deploy/$KRE_DEPLOY" -- cat /data/results/remediation-events.jsonl \
  > "$RUN_DIR/kre-audit.jsonl" 2> "$RUN_DIR/kre-audit.err" || echo "[!] KRE audit log not retrieved (see kre-audit.err)"
jq --arg end "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '. + {finished:$end}' "$RUN_DIR/run.json" > "$RUN_DIR/run.tmp" && mv "$RUN_DIR/run.tmp" "$RUN_DIR/run.json"
echo "[+] collection complete: $RUN_DIR"
python3 "$SCRIPT_DIR/compute_runtime_metrics.py" "$RUN_DIR"
