#!/usr/bin/env python3
"""
Compute Layer 4 metrics from one runtime-suite run directory.

Inputs (written by scripts/run-runtime-suite.sh):
  run.json, scenarios.tsv, scenarios/<scenario>__rep<k>/{state.json,pod.log},
  benign/*.json, falco/*.log, kre-audit.jsonl

Definitions (time unit: seconds unless suffixed _ms):
  detected   : a Falco event whose rule == expected_rule for that pod, inside
               [t_apply, t_observe_end]
  MTTD       : first expected-rule event time - MSEF_ATTACK_START log timestamp
  contained  : KRE audit record for that pod and rule with success=true AND the
               harness's own end-state check agrees (pod absent / new UID for
               plans that terminate; attack RoleBinding absent for revoke plans)
  MTTC       : KRE t_confirmed - t_received (alert ingestion -> confirmed state),
               over successfully contained scenarios only
  E2EML      : KRE t_confirmed - attack start
  RDR        : detected / all scenario repetitions (missing or failed ones count)
  RRSR       : contained / detected
  OFPR       : benign windows with >= 1 MSEF alert / benign windows
Missing values are reported as null and counted; nothing is imputed.
"""
import glob, json, math, os, statistics, sys
from datetime import datetime

def ts(s):
    if s is None: return None
    if isinstance(s, (int, float)): return float(s)
    s = s.strip().replace("Z", "+00:00")
    if "." in s:  # trim sub-microsecond digits for fromisoformat
        head, frac = s.split(".", 1)
        tz = ""
        for sep in ("+", "-"):
            if sep in frac: frac, tz = frac.split(sep, 1); tz = sep + tz; break
        s = f"{head}.{frac[:6]}{tz}"
    return datetime.fromisoformat(s).timestamp()

def wilson(k, n, z=1.959964):
    if n == 0: return [None, None]
    p = k / n; d = 1 + z*z/n
    c = (p + z*z/(2*n)) / d; h = z*math.sqrt(p*(1-p)/n + z*z/(4*n*n)) / d
    return [round(max(0, c-h), 4), round(min(1, c+h), 4)]

def summary(xs):
    xs = [x for x in xs if x is not None]
    if not xs: return {"n": 0, "mean": None, "median": None, "sd": None, "ci95": [None, None], "ci_method": None}
    n = len(xs); m = statistics.fmean(xs); sd = statistics.stdev(xs) if n > 1 else None
    ci, method = [None, None], None
    if n > 1:
        try:
            from scipy import stats
            tq = stats.t.ppf(0.975, n-1); method = "t"
        except ImportError:
            tq = 1.959964; method = "normal-approx (scipy not installed)"
        h = tq * sd / math.sqrt(n); ci = [m-h, m+h]
    r = lambda v: None if v is None else round(v, 6)
    return {"n": n, "mean": r(m), "median": r(statistics.median(xs)), "sd": r(sd),
            "min": r(min(xs)), "max": r(max(xs)), "ci95": [r(ci[0]), r(ci[1])], "ci_method": method}

def load_falco(run):
    seen, events = set(), []
    for f in glob.glob(os.path.join(run, "falco", "*.log")):
        for line in open(f, errors="replace"):
            line = line.strip()
            if not line.startswith("{"): continue
            try: e = json.loads(line)
            except json.JSONDecodeError: continue
            key = (e.get("time"), e.get("rule"), json.dumps(e.get("output_fields", {}), sort_keys=True))
            if key in seen: continue
            seen.add(key); e["_t"] = ts(e.get("time")); events.append(e)
    return events

def main(run):
    run_meta = json.load(open(os.path.join(run, "run.json")))
    falco = load_falco(run)
    kre = []
    p = os.path.join(run, "kre-audit.jsonl")
    if os.path.exists(p):
        for line in open(p):
            try: kre.append(json.loads(line))
            except json.JSONDecodeError: pass
    rows = []
    for st_path in sorted(glob.glob(os.path.join(run, "scenarios", "*", "state.json"))):
        st = json.load(open(st_path)); d = os.path.dirname(st_path)
        row = {"scenario": st["scenario"], "rep": st["rep"], "error": st.get("error")}
        if st.get("error"):
            row.update(detected=False, contained=False); rows.append(row); continue
        t0, t1, pod, rule = ts(st["t_apply"]), ts(st["t_observe_end"]), st["pod"], st["expected_rule"]
        attack_start = None
        lp = os.path.join(d, "pod.log")
        if os.path.exists(lp):
            for line in open(lp, errors="replace"):
                if "MSEF_ATTACK_START" in line:
                    attack_start = ts(line.split(" ", 1)[0]); break
        ev = [e for e in falco if e["_t"] is not None and t0 <= e["_t"] <= t1
              and (e.get("output_fields") or {}).get("k8s.pod.name") == pod
              and (e.get("output_fields") or {}).get("k8s.ns.name") == "hardened"]
        hits = sorted((e for e in ev if e.get("rule") == rule), key=lambda e: e["_t"])
        t_detect = hits[0]["_t"] if hits else None
        recs = sorted((r for r in kre if r.get("target_pod") == pod and r.get("falco_rule") == rule
                       and r.get("status") == "processed" and r.get("t_received") is not None
                       and t0 <= r["t_received"] <= t1), key=lambda r: r["t_received"])
        rec = recs[0] if recs else None
        terminates = "TERMINATE" in st["expected_action"]; revokes = "REVOKE" in st["expected_action"]
        state_ok = True
        if terminates: state_ok &= st["pod_phase_at_end"] == "absent" or (rec is not None and st["pod_uid_at_end"] not in ("", rec.get("target_pod_uid")))
        if revokes: state_ok &= st["attack_rolebinding_present_at_end"] is False
        row.update(
            attack_start=attack_start, t_detect=t_detect, detected=bool(hits),
            other_rules_on_pod=sorted({e.get("rule") for e in ev} - {rule}),
            mttd_s=(t_detect - attack_start) if (t_detect and attack_start) else None,
            kre_record=bool(rec), kre_action=rec.get("action_taken") if rec else None,
            kre_success=rec.get("success") if rec else None, end_state_confirmed=state_ok,
            contained=bool(hits) and bool(rec) and bool(rec.get("success")) and state_ok,
            mttc_s=rec.get("mttc_seconds") if rec else None,
            queue_wait_s=rec.get("queue_wait_seconds") if rec else None,
            e2eml_s=(rec["t_confirmed"] - attack_start) if (rec and rec.get("t_confirmed") and attack_start) else None)
        rows.append(row)

    total = len(rows); det = sum(r["detected"] for r in rows); con = sum(r.get("contained", False) for r in rows)
    benign = []
    for bp in sorted(glob.glob(os.path.join(run, "benign", "*.json"))):
        b = json.load(open(bp)); b0, b1 = ts(b["t_start"]), ts(b["t_end"])
        alerts = [e for e in falco if e["_t"] and b0 <= e["_t"] <= b1 and str(e.get("rule", "")).startswith("MSEF ")]
        benign.append({"window": b["window"], "msef_alerts": len(alerts), "rules": sorted({e["rule"] for e in alerts})})
    fp_windows = sum(1 for b in benign if b["msef_alerts"] > 0)
    status_counts = {}
    for r in kre: status_counts[r.get("status", "?")] = status_counts.get(r.get("status", "?"), 0) + 1
    attack_pods = {r["scenario"] for r in rows}
    stray = [e for e in falco if str(e.get("rule", "")).startswith("MSEF ")
             and (e.get("output_fields") or {}).get("k8s.pod.name") not in attack_pods]
    mttd = summary([r.get("mttd_s") for r in rows]); mttc = summary([r.get("mttc_s") for r in rows if r.get("contained")])  # successful containments only
    out = {
        "run": run_meta,
        "rdr": {"detected": det, "total": total, "score": round(det/total, 4) if total else None, "ci95_wilson": wilson(det, total)},
        "rrsr": {"contained": con, "detected": det, "score": round(con/det, 4) if det else None, "ci95_wilson": wilson(con, det)},
        "mttd_seconds": mttd, "mttc_seconds": mttc,
        "e2eml_seconds": summary([r.get("e2eml_s") for r in rows if r.get("contained")]),
        "queue_wait_seconds": summary([r.get("queue_wait_s") for r in rows]),
        "ofpr": {"false_alert_windows": fp_windows, "windows": len(benign),
                 "score": round(fp_windows/len(benign), 4) if benign else None,
                 "ci95_wilson": wilson(fp_windows, len(benign)), "windows_detail": benign},
        "msef_alerts_on_non_attack_pods": len(stray),
        "kre_audit_status_counts": status_counts,
        "kre_events_lost": status_counts.get("dropped_queue_full", 0) + status_counts.get("worker_error", 0),
        "per_scenario": rows,
    }
    json.dump(out, open(os.path.join(run, "metrics.json"), "w"), indent=2)
    # Compatibility files for PES/DES scripts; provenance travels with every value.
    jd = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(run))), "json")
    os.makedirs(jd, exist_ok=True); prov = {"run_id": run_meta["run_id"], "git_commit": run_meta.get("git_commit")}
    json.dump({"metric": "RDR", **out["rdr"], **prov}, open(os.path.join(jd, "rdr.json"), "w"), indent=2)
    json.dump({"metric": "RRSR", **out["rrsr"], "mttc_seconds": mttc, **prov}, open(os.path.join(jd, "rrsr.json"), "w"), indent=2)
    json.dump({"metric": "MTTD", "unit": "seconds", "mean_time_to_detect_s": mttd["mean"], **mttd, **prov}, open(os.path.join(jd, "mttd.json"), "w"), indent=2)
    json.dump({"metric": "OFPR", **{k: v for k, v in out["ofpr"].items() if k != "windows_detail"}, **prov}, open(os.path.join(jd, "fpr.json"), "w"), indent=2)
    print(json.dumps({k: out[k] for k in ("rdr", "rrsr", "ofpr", "kre_events_lost")}, indent=2))
    print("MTTD", mttd, "\nMTTC", mttc)

if __name__ == "__main__":
    if len(sys.argv) != 2: sys.exit("usage: compute_runtime_metrics.py results/runs/<run_id>")
    main(sys.argv[1])
