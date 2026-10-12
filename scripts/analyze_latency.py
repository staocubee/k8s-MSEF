#!/usr/bin/env python3
"""
Statistics for admission-latency runs written by bench_admission.py.

  analyze_latency.py --baseline results/runs/bench-C0-... results/runs/bench-C5-... [...]

Per run (successful requests only; failures are counted and reported):
  n, mean, sample SD, P50/P90/P95/P99 (linear interpolation), failures.
Per run vs. baseline:
  Welch's t (t, df, two-sided p), Mann-Whitney U (two-sided p),
  Cohen's d (pooled sample SD) and Hedges' g, and percentile-bootstrap 95% CIs
  (B=10000, fixed seed) for the differences in median and in P99.
Latency is typically right-skewed: report the non-parametric results and the
bootstrap CIs alongside (not instead of) Welch's test.
Resource footprint: mean / P95 / max of sampled CPU and memory per namespace,
with the sample count; empty if metrics were unavailable.
"""
import argparse, csv, json, math, os
import numpy as np
from scipy import stats

def load(run):
    rows = list(csv.DictReader(open(os.path.join(run, "latencies.csv"))))
    ok = np.array([float(r["latency_ms"]) for r in rows if r["ok"] == "True"])
    return ok, sum(r["ok"] != "True" for r in rows), json.load(open(os.path.join(run, "run.json")))

def desc(x, failed):
    if len(x) == 0: return {"n": 0, "failed": failed}
    q = np.percentile(x, [50, 90, 95, 99])
    return {"n": int(len(x)), "failed": failed, "mean_ms": round(float(x.mean()), 3),
            "sd_ms": round(float(x.std(ddof=1)), 3) if len(x) > 1 else None,
            "p50_ms": round(float(q[0]), 3), "p90_ms": round(float(q[1]), 3),
            "p95_ms": round(float(q[2]), 3), "p99_ms": round(float(q[3]), 3)}

def boot(a, b, fn, B=10000, seed=12345):
    rng = np.random.default_rng(seed)
    d = np.array([fn(rng.choice(b, len(b))) - fn(rng.choice(a, len(a))) for _ in range(B)])
    return [round(float(np.percentile(d, 2.5)), 3), round(float(np.percentile(d, 97.5)), 3)]

def compare(a, b):
    w = stats.ttest_ind(b, a, equal_var=False)
    va, vb = a.var(ddof=1) / len(a), b.var(ddof=1) / len(b)
    df = (va + vb) ** 2 / (va ** 2 / (len(a) - 1) + vb ** 2 / (len(b) - 1))
    sp = math.sqrt(((len(a) - 1) * a.var(ddof=1) + (len(b) - 1) * b.var(ddof=1)) / (len(a) + len(b) - 2))
    d = (b.mean() - a.mean()) / sp
    g = d * (1 - 3 / (4 * (len(a) + len(b)) - 9))
    mw = stats.mannwhitneyu(b, a, alternative="two-sided")
    return {"welch_t": round(float(w.statistic), 3), "welch_df": round(float(df), 1), "welch_p": float(w.pvalue),
            "mannwhitney_u": float(mw.statistic), "mannwhitney_p": float(mw.pvalue),
            "cohens_d": round(float(d), 3), "hedges_g": round(float(g), 3),
            "delta_mean_ms": round(float(b.mean() - a.mean()), 3),
            "delta_median_ms": round(float(np.median(b) - np.median(a)), 3),
            "delta_median_ci95_bootstrap": boot(a, b, np.median),
            "delta_p99_ms": round(float(np.percentile(b, 99) - np.percentile(a, 99)), 3),
            "delta_p99_ci95_bootstrap": boot(a, b, lambda x: np.percentile(x, 99))}

def resources(run):
    p = os.path.join(run, "resources.csv")
    if not os.path.exists(p): return {}
    out = {}
    for r in csv.DictReader(open(p)):
        if not r["cpu_millicores"]: continue
        k = r["namespace"]; out.setdefault(k, {"cpu": [], "mem": []})
        out[k]["cpu"].append(float(r["cpu_millicores"])); out[k]["mem"].append(float(r["memory_mib"]))
    s = lambda v: {"n": len(v), "mean": round(float(np.mean(v)), 2), "p95": round(float(np.percentile(v, 95)), 2), "max": round(float(np.max(v)), 2)}
    return {k: {"cpu_millicores_per_pod_sample": s(v["cpu"]), "memory_mib_per_pod_sample": s(v["mem"])} for k, v in out.items()}

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--baseline", required=True); ap.add_argument("runs", nargs="+")
    ap.add_argument("--out", default=None); a = ap.parse_args()
    base, bf, bm = load(a.baseline)
    res = {"baseline": {"run": bm["run_id"], "config": bm["config"], **desc(base, bf), "resources": resources(a.baseline)}, "runs": []}
    for r in a.runs:
        x, f, m = load(r)
        entry = {"run": m["run_id"], "config": m["config"], **desc(x, f), "resources": resources(r)}
        if len(x) > 1 and len(base) > 1: entry["vs_baseline"] = compare(base, x)
        res["runs"].append(entry)
    out = a.out or os.path.join(os.path.dirname(os.path.abspath(a.runs[-1])), f"latency-analysis-{bm['config']}-vs-{'-'.join(e['config'] for e in res['runs'])}.json")
    json.dump(res, open(out, "w"), indent=2); print(json.dumps(res, indent=2)); print(f"[+] {out}")

if __name__ == "__main__":
    main()
