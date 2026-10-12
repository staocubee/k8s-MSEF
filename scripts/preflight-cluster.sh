#!/usr/bin/env bash
# Refuse to evaluate a cluster that is not fully deployed. Read-only.
set -euo pipefail
fail=0; ok() { echo "[ok]   $1"; }; bad() { echo "[FAIL] $1"; fail=1; }
apps="$(kubectl -n argocd get applications -o json 2>/dev/null || echo '{"items":[]}')"
n=$(jq '.items|length' <<<"$apps")
notready=$(jq -r '.items[]|select(.status.sync.status!="Synced" or .status.health.status!="Healthy")|.metadata.name' <<<"$apps")
if [[ "$n" -gt 0 && -z "$notready" ]]; then ok "Argo CD: $n applications Synced/Healthy"; else bad "Argo CD apps not ready: ${notready:-none found}"; fi
if kubectl get validatingwebhookconfigurations -o name | grep -qi gatekeeper; then ok "Gatekeeper webhook"; else bad "Gatekeeper webhook missing"; fi
if kubectl get validatingwebhookconfigurations -o name | grep -qi kyverno; then ok "Kyverno webhook"; else bad "Kyverno webhook missing"; fi
if kubectl get clusterpolicy verify-signed-images >/dev/null 2>&1; then ok "Kyverno verify-signed-images"; else bad "verify-signed-images policy missing"; fi
d=$(kubectl -n falco get ds -o jsonpath='{.items[0].status.desiredNumberScheduled}' 2>/dev/null || echo 0)
r=$(kubectl -n falco get ds -o jsonpath='{.items[0].status.numberReady}' 2>/dev/null || echo 0)
if [[ "${d:-0}" -gt 0 && "$d" == "$r" ]]; then ok "Falco $r/$d ready"; else bad "Falco ${r:-0}/${d:-0} ready"; fi
kr=$(kubectl -n hardened get deploy msef-kre-handler -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [[ "${kr:-0}" -ge 1 ]]; then ok "KRE ready"; else bad "KRE not ready"; fi
if kubectl -n hardened logs deploy/msef-kre-handler 2>/dev/null | grep -q "rule plans"; then ok "KRE loaded rule plans"; else bad "KRE rule plans not confirmed in logs"; fi
if kubectl top pods -n falco >/dev/null 2>&1; then ok "metrics-server"; else bad "metrics-server unavailable (resource metrics would be null)"; fi
if [[ $fail != 0 ]]; then echo "Cluster not ready for evaluation."; exit 1; fi
