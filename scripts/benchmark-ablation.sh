#!/usr/bin/env bash
# =============================================================================
# MSEFv2 component ablation, one configuration per invocation.
#
# This script does NOT reconfigure the cluster (removing admission webhooks or
# Falco is disruptive and must be done deliberately by the operator, e.g. by
# suspending the corresponding Argo CD applications). It:
#   1. checks that the live cluster matches the requested configuration and
#      refuses to run if it does not (override with --force, recorded in run.json)
#   2. runs the real measurement harnesses appropriate to that configuration
# Results from all six invocations are then compared with analyze_latency.py
# and the per-run metrics.json files. No values are hardcoded.
#
# Expected component state per configuration:
#   C0 vanilla        : no Gatekeeper/Kyverno webhooks, no Falco, no KRE
#   C1 shift-left only: identical cluster state to C0 (Trivy/Snyk run in CI,
#                       outside the cluster), so cluster metrics equal C0 by design
#   C2 admission only : Gatekeeper + Kyverno, no Falco, no KRE
#   C3 detection only : Falco, no admission webhooks, no KRE
#   C4 sync KRE       : all components, KRE_MODE=sync
#   C5 full MSEFv2    : all components, KRE_MODE=async
# PSA namespace labels are reported as found; remove them for a strict C0.
#
# Usage: scripts/benchmark-ablation.sh C5 [--requests 500] [--repeats 3] [--force]
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${1:?usage: benchmark-ablation.sh C0|C1|C2|C3|C4|C5 [--requests N] [--repeats N] [--force]}"; shift
REQUESTS=500; REPEATS=3; FORCE=0
while [[ $# -gt 0 ]]; do case "$1" in
  --requests) REQUESTS="$2"; shift 2;; --repeats) REPEATS="$2"; shift 2;; --force) FORCE=1; shift;;
  *) echo "unknown arg $1" >&2; exit 2;; esac; done

has_webhook() { kubectl get validatingwebhookconfigurations -o name 2>/dev/null | grep -qi "$1"; }
GK=false; KY=false; FALCO=false; KRE=false; MODE=""
has_webhook gatekeeper && GK=true
has_webhook kyverno && KY=true
[[ "$(kubectl get ds -n falco -o name 2>/dev/null | wc -l)" -gt 0 ]] && FALCO=true
if kubectl get deploy -n hardened msef-kre-handler >/dev/null 2>&1; then
  [[ "$(kubectl get deploy -n hardened msef-kre-handler -o jsonpath='{.status.readyReplicas}')" -ge 1 ]] 2>/dev/null && KRE=true
  MODE="$(kubectl get deploy -n hardened msef-kre-handler -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="KRE_MODE")].value}')"
fi
PSA="$(kubectl get ns hardened -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || true)"
echo "[*] live state: gatekeeper=$GK kyverno=$KY falco=$FALCO kre=$KRE kre_mode=${MODE:-n/a} psa_enforce=${PSA:-none}"

case "$CFG" in
  C0|C1) WANT="false false false false -";;  C2) WANT="true true false false -";;
  C3) WANT="false false true false -";;     C4) WANT="true true true true sync";;
  C5) WANT="true true true true async";;    *) echo "unknown config $CFG" >&2; exit 2;;
esac
read -r WGK WKY WFA WKR WMO <<<"$WANT"
MISMATCH=""
[[ "$GK" != "$WGK" ]] && MISMATCH+=" gatekeeper($GK!=$WGK)"
[[ "$KY" != "$WKY" ]] && MISMATCH+=" kyverno($KY!=$WKY)"
[[ "$FALCO" != "$WFA" ]] && MISMATCH+=" falco($FALCO!=$WFA)"
[[ "$KRE" != "$WKR" ]] && MISMATCH+=" kre($KRE!=$WKR)"
[[ "$WMO" != "-" && "$MODE" != "$WMO" ]] && MISMATCH+=" kre_mode($MODE!=$WMO)"
if [[ -n "$MISMATCH" ]]; then
  echo "[!] cluster does not match $CFG:$MISMATCH" >&2
  [[ "$FORCE" == 1 ]] || { echo "    reconfigure the cluster, or pass --force (recorded)" >&2; exit 1; }
fi
export MSEF_ABLATION_FORCED="$FORCE" MSEF_ABLATION_MISMATCH="${MISMATCH:-none}"

for i in $(seq 1 "$REPEATS"); do
  echo "[*] $CFG latency trial $i/$REPEATS"
  python3 "$SCRIPT_DIR/bench_admission.py" --config "$CFG" --requests "$REQUESTS"
done
if [[ "$WGK" == true ]]; then
  python3 "$SCRIPT_DIR/measure_admission.py" mbr --seed "${MSEF_FUZZ_SEED:-20261012}" || echo "[!] MBR run failed or invalid"
  python3 "$SCRIPT_DIR/measure_admission.py" spr --repeats 2 || echo "[!] SPR run failed or invalid"
fi
if [[ "$WFA" == true ]]; then
  "$SCRIPT_DIR/run-runtime-suite.sh" --repeats "$REPEATS" --config-label "$CFG"
fi
echo "[+] $CFG complete. Compare: python3 scripts/analyze_latency.py --baseline <C0 bench run> <this config's bench runs>"
