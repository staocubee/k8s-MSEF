# MSEFv2 experiment runbook

Branch `msefv2-harness-fixes` implements the "minimal code fixes" from the
October 2026 evidence audit. **Nothing on this branch has been run against a
cluster.** Offline checks only: KRE controller tests against a fake API
(`python3 tests/test_kre_handler.py`, 20/20; `python3 tests/test_rule_consistency.py`, 8/8), fuzzer determinism and
distinctness, admission-oracle cases, metric calculators on fixtures.
Falco rule syntax has not been validated by Falco itself (step 2 does that).

Run order matters: fix → verify deployment → experiments → manuscript.
All results go to `results/runs/<run_id>/` with run metadata (git commit,
cluster version, component images, seed). `results/json/*.json` holds the
latest value per metric *with its run_id*. v1 results are archived under
`results/archive-v1-pre-f413715/` and must not be cited.

## Changing runtime rules
Falco rules, KRE containment and the harness must stay in step. A rule change touches three files:
1. `gitops/platform/dev/falco/values.yaml` (`customRules`): the detection rule
2. `gitops/platform/dev/kre/configmap.yaml` (`rule-plans.json`): its containment plan;
   then bump `msef.security/rule-plans-version` in `kre/deployment.yaml` so the pod restarts
   and reloads the map (environment variables from a ConfigMap are read only at start)
3. `k8s/runtime-tests/scenarios.tsv`: the scenario that exercises it

Then run `python3 tests/test_rule_consistency.py` before committing. KRE only remediates
rules present in the map; anything else is audited as `unsupported_rule` and left alone.

## 0. Prerequisites
- `pip install -r scripts/requirements.txt`; `jq`; kubectl context on the dev cluster
- metrics-server available (`kubectl top pods -n falco` works)
- GKE NetworkPolicy enforcement enabled (Dataplane V2 or Calico); otherwise
  quarantine policies exist but are not enforced

## 1. Build and sign the KRE image
Run the **Build and Sign KRE Image** workflow with tag `v2.1.0`. Kyverno
rejects unsigned `staocube/*` images in `hardened`, so KRE cannot start without this.

## 2. Sync and verify the deployment (C5 state)
Sync Argo CD apps: falco, falcosidekick, kre-handler. Then check:
- `kubectl -n hardened get pods -l app=msef-kre-handler` → Running, Ready
- `kubectl -n hardened exec deploy/msef-kre-handler -- python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8080/healthz').read())"` → `mode: async`
- `kubectl -n falco logs ds/<falco> -c falco | grep -i "msef"` → rules loaded, no rule errors
- `kubectl -n hardened logs deploy/msef-kre-handler | grep "rule plans"` → `10 rule plans`
- Two Falcosidekick instances exist (chart-embedded and the standalone app);
  both now post to KRE. KRE's dedup absorbs duplicates, but disable one to keep
  the event accounting clean.

## 3. Experiments (one configuration per run of benchmark-ablation.sh)
Start with C5 (everything on), then C4, then reconfigure for C3, C2, C0.
`benchmark-ablation.sh` verifies the live state and refuses on mismatch.

| Config | How to reach it | Command |
| --- | --- | --- |
| C5 | default after step 2 | `scripts/benchmark-ablation.sh C5 --requests 500 --repeats 3` |
| C4 | set `KRE_MODE=sync` in `kre/deployment.yaml`, sync | `scripts/benchmark-ablation.sh C4 ...` |
| C3 | suspend Gatekeeper, Kyverno, KRE apps; keep Falco | `... C3 ...` |
| C2 | Gatekeeper + Kyverno on; suspend Falco and KRE | `... C2 ...` |
| C0 | suspend all four; optionally drop PSA labels on `hardened` | `... C0 ...` |
| C1 | same cluster state as C0 by design; report Layer 1 scans separately | — |

Each invocation runs, as applicable: latency trials (`bench_admission.py`),
MBR (`measure_admission.py mbr --seed 20261012`), SPR/IES
(`measure_admission.py spr`), runtime suite (`run-runtime-suite.sh`: 10
scenarios × repeats, plus benign windows for OFPR).

Then:
- latency statistics: `python3 scripts/analyze_latency.py --baseline results/runs/bench-C0-<ts> results/runs/bench-C2-<ts> results/runs/bench-C5-<ts> ...`
- Layer 1 (Table 2): re-run `pre-deployment/scripts/run-predeployment-evaluation.sh`; 3 of 5 Snyk outputs were empty in v1
- NPER / SMER: `scripts/measure-nper.sh`, `scripts/measure-smer.sh` (unchanged from v1; review their oracles before citing)
- composites: `scripts/measure-pes.sh`, `scripts/measure-des.sh` (fail if any input is missing)
- tables: `python3 scripts/export_results_tables.py > results/manuscript-tables.md`

Commit every `results/runs/<run_id>/` directory used in the paper.

## 4. Manuscript
Rewrite the results only from `results/manuscript-tables.md` and the cited run
directories. Values not yet measured stay out of the paper.

## Known limitations still open
- NetworkPolicy *enforcement* is not verified by KRE (`network_enforcement_verified: false`); add a connectivity probe from a quarantined pod if the paper claims enforced isolation.
- KRE's queue and dedup state are in memory; events in flight are lost on restart (the audit log persists on the PVC).
- Runtime tests are behavioural simulations (e.g. the cgroup test writes a file named `release_agent`; the mining test connects to a TEST-NET address). Describe them as simulations.
- MITRE IDs in `k8s/runtime-tests/scenarios.tsv` are candidates to verify; CIS numbering in the fuzzer is replaced by descriptive PSS/org-policy labels.
- `measure-nper.sh`, `measure-smer.sh` and the Layer 1 scripts were not part of this fix set.
