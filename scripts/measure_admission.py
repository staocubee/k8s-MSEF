#!/usr/bin/env python3
"""
Admission-layer measurements with an explicit oracle.

  measure_admission.py mbr --seed N [--count 100]   # Layer 2, mutation corpus
  measure_admission.py spr [--repeats 1]            # Layer 3, image integrity

Oracle (applied to `kubectl apply --dry-run=server` output):
  ADMITTED  exit status 0
  BLOCKED   an admission webhook explicitly denied the request, or the request
            violates PodSecurity; the enforcer and message are recorded
  ERROR     anything else (missing namespace, auth/TLS/network failure, schema
            error). ERRORs are reported and excluded from the denominator.
Each run aborts as INVALID if its positive control is not ADMITTED.
"""
import argparse, json, os, re, shutil, subprocess, sys, tempfile, time
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEBHOOK_DENY = re.compile(r'admission webhook "([^"]+)" denied the request:?\s*(.*)', re.S)
PSA_DENY = re.compile(r'violates PodSecurity "([^"]+)"[^:]*:?\s*(.*)', re.S)

def sh(*args, **kw):
    return subprocess.run(list(args), capture_output=True, text=True, **kw)

def classify(proc):
    out = (proc.stdout + proc.stderr).strip()
    if proc.returncode == 0:
        return "ADMITTED", None, out
    m = WEBHOOK_DENY.search(out)
    if m:
        hook = m.group(1)
        enf = "gatekeeper" if "gatekeeper" in hook else "kyverno" if "kyverno" in hook else hook
        return "BLOCKED", enf, out
    m = PSA_DENY.search(out)
    if m:
        return "BLOCKED", "pod-security-admission", out
    return "ERROR", None, out

def dry_run(path):
    return classify(sh("kubectl", "apply", "--dry-run=server", "-f", path))

def run_meta(kind, extra):
    v = sh("kubectl", "version", "-o", "json")
    server = json.loads(v.stdout).get("serverVersion", {}).get("gitVersion") if v.returncode == 0 else None
    img = lambda ns, sel: sh("kubectl", "get", "pods", "-n", ns, "-l", sel, "-o",
                             "jsonpath={.items[0].spec.containers[0].image}").stdout or None
    return {"kind": kind, "started": datetime.now(timezone.utc).isoformat(),
            "git_commit": sh("git", "-C", ROOT, "rev-parse", "HEAD").stdout.strip() or None,
            "kube_context": sh("kubectl", "config", "current-context").stdout.strip() or None,
            "server_version": server,
            "gatekeeper_image": img("gatekeeper-system", "control-plane=controller-manager"),
            "kyverno_image": img("kyverno", "app.kubernetes.io/component=admission-controller"),
            **extra}

def new_run_dir(prefix):
    rid = f"{prefix}-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}"
    d = os.path.join(ROOT, "results", "runs", rid); os.makedirs(d); return rid, d

def write_tsv(path, rows, cols):
    with open(path, "w") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r.get(c, "")).replace("\t", " ").replace("\n", " ")[:500] for c in cols) + "\n")

def wilson(k, n, z=1.959964):
    if n == 0: return [None, None]
    import math
    p = k/n; d = 1 + z*z/n; c = (p + z*z/(2*n))/d; h = z*math.sqrt(p*(1-p)/n + z*z/(4*n*n))/d
    return [round(max(0, c-h), 4), round(min(1, c+h), 4)]

def cmd_mbr(a):
    rid, d = new_run_dir("mbr")
    corpus = os.path.join(d, "corpus")
    gen = sh(sys.executable, os.path.join(ROOT, "scripts", "fuzz_manifests.py"), "--seed", str(a.seed),
             "--count", str(a.count), "--namespace", a.namespace, "--outdir", corpus)
    if gen.returncode: sys.exit(gen.stderr)
    meta = run_meta("mbr", {"run_id": rid, **json.load(open(os.path.join(corpus, "corpus.json")))})
    ctl = dry_run(os.path.join(corpus, "control-seed.yaml"))
    meta["control_seed"] = {"outcome": ctl[0], "enforcer": ctl[1], "output": ctl[2][:2000]}
    rows = []
    lines = open(os.path.join(corpus, "manifest_ground_truth.tsv")).read().splitlines()
    cols = lines[0].split("\t")
    for line in lines[1:]:
        r = dict(zip(cols, line.split("\t")))
        outcome, enf, out = dry_run(os.path.join(corpus, r["file"]))
        r.update(outcome=outcome, enforcer=enf or "", message=out)
        rows.append(r)
        time.sleep(a.pause)
    write_tsv(os.path.join(d, "results.tsv"), rows, cols + ["outcome", "enforcer", "message"])
    deny = [r for r in rows if r["expected"] == "deny"]
    blocked = sum(r["outcome"] == "BLOCKED" for r in deny)
    bypass = [r for r in deny if r["outcome"] == "ADMITTED"]
    errors = sum(r["outcome"] == "ERROR" for r in rows)
    n = blocked + len(bypass)
    valid = ctl[0] == "ADMITTED"
    res = {"metric": "MBR", "run_id": rid, "valid": valid,
           "invalid_reason": None if valid else f"control seed {ctl[0]}",
           "blocked": blocked, "bypassed": len(bypass), "errors_excluded": errors, "evaluated": n,
           "score": round(blocked/n, 4) if (n and valid) else None, "ci95_wilson": wilson(blocked, n),
           "by_enforcer": {e: sum(r["enforcer"] == e for r in deny) for e in sorted({r["enforcer"] for r in deny if r["enforcer"]})},
           "bypassed_operators": sorted({r["operators"] for r in bypass}),
           "seed": a.seed, "git_commit": meta["git_commit"]}
    json.dump(meta, open(os.path.join(d, "run.json"), "w"), indent=2)
    json.dump(res, open(os.path.join(d, "mbr.json"), "w"), indent=2)
    os.makedirs(os.path.join(ROOT, "results", "json"), exist_ok=True)
    shutil.copy(os.path.join(d, "mbr.json"), os.path.join(ROOT, "results", "json", "mbr.json"))
    print(json.dumps(res, indent=2))
    if not valid: sys.exit("INVALID RUN: the unmutated control seed was not admitted; fix the seed or cluster first")

def cmd_spr(a):
    rid, d = new_run_dir("spr")
    tdir = os.path.join(ROOT, "k8s", "integrity-tests")
    exp = [l.split("\t") for l in open(os.path.join(tdir, "expected.tsv")).read().splitlines()[1:]]
    rows = []
    for rep in range(1, a.repeats + 1):
        for mf, expected, note in exp:
            src = open(os.path.join(tdir, mf)).read()
            # unique pod name per attempt so repetitions are independent requests
            src = re.sub(r"(\n  name:\s*)(\S+)", lambda m: f"{m.group(1)}{m.group(2)}-r{rep}", src, count=1)
            with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as t:
                t.write(src); path = t.name
            outcome, enf, out = dry_run(path); os.unlink(path)
            sig = outcome == "BLOCKED" and enf == "kyverno" and "verify-signed-images" in out
            rows.append({"rep": rep, "manifest": mf, "expected": expected, "outcome": outcome,
                         "enforcer": enf or "", "kyverno_signature_denial": sig, "note": note, "message": out})
    write_tsv(os.path.join(d, "results.tsv"), rows,
              ["rep", "manifest", "expected", "outcome", "enforcer", "kyverno_signature_denial", "note", "message"])
    ctl = [r for r in rows if r["expected"] == "admit"]
    valid = bool(ctl) and all(r["outcome"] == "ADMITTED" for r in ctl)
    deny = [r for r in rows if r["expected"] == "deny" and r["outcome"] != "ERROR"]
    k = sum(r["kyverno_signature_denial"] for r in deny)
    res = {"metric": "SPR", "run_id": rid, "valid": valid,
           "invalid_reason": None if valid else "signed positive control not admitted",
           "rejected_by_signature_policy": k, "evaluated": len(deny),
           "blocked_by_other_policy": sum(r["outcome"] == "BLOCKED" and not r["kyverno_signature_denial"] for r in deny),
           "errors_excluded": sum(r["outcome"] == "ERROR" for r in rows),
           "out_of_scope_admitted": sum(r["expected"] == "out_of_scope" and r["outcome"] == "ADMITTED" for r in rows),
           "score": round(k/len(deny), 4) if (deny and valid) else None, "ci95_wilson": wilson(k, len(deny))}
    meta = run_meta("spr", {"run_id": rid, "repeats": a.repeats})
    res["git_commit"] = meta["git_commit"]
    json.dump(meta, open(os.path.join(d, "run.json"), "w"), indent=2)
    json.dump(res, open(os.path.join(d, "spr.json"), "w"), indent=2)
    jd = os.path.join(ROOT, "results", "json"); os.makedirs(jd, exist_ok=True)
    shutil.copy(os.path.join(d, "spr.json"), os.path.join(jd, "spr.json"))
    json.dump({"metric": "IES", "spr": res["score"], "score": res["score"], "run_id": rid, "git_commit": res["git_commit"]},
              open(os.path.join(jd, "ies.json"), "w"), indent=2)
    print(json.dumps(res, indent=2))
    if not valid: sys.exit("INVALID RUN: the signed positive control was not admitted")

if __name__ == "__main__":
    ap = argparse.ArgumentParser(); sub = ap.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("mbr"); m.add_argument("--seed", type=int, required=True)
    m.add_argument("--count", type=int, default=100); m.add_argument("--namespace", default="hardened")
    m.add_argument("--pause", type=float, default=0.0)
    s = sub.add_parser("spr"); s.add_argument("--repeats", type=int, default=1)
    a = ap.parse_args(); {"mbr": cmd_mbr, "spr": cmd_spr}[a.cmd](a)
