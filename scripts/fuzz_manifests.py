#!/usr/bin/env python3
"""
MSEF manifest mutation fuzzer.

Generates N *distinct* mutants from a compliant seed. Each mutant is a
composition of 1..MAX_ORDER mutation operators (mu_k o ... o mu_1)(S), drawn
without replacement from the enumerated candidate space with a fixed seed.

Every mutant carries an `expected` decision under the declared policy intent:
  deny  - the mutant violates an intended control and should be rejected
  admit - the control seed (positive control) or a known-admissible variant
Bypasses are therefore measurable: an admitted 'deny' mutant is a bypass.

Outputs (in --outdir): mutant YAML files, control-seed.yaml,
manifest_ground_truth.tsv and corpus.json (seed, parameters, operator ids).
CIS / PSS references are descriptive labels; verify numbering against the
benchmark version you cite.
"""
import argparse, copy, hashlib, itertools, json, os, random
import yaml

def seed_pod(ns):
    return {"apiVersion": "v1", "kind": "Pod",
            "metadata": {"name": "seed", "namespace": ns, "labels": {"app": "msef-fuzz"}},
            "spec": {"serviceAccountName": "hardened-app-sa", "automountServiceAccountToken": False,
                     "securityContext": {"runAsNonRoot": True, "seccompProfile": {"type": "RuntimeDefault"}},
                     "containers": [{"name": "app", "image": "registry.k8s.io/pause:3.9",
                         "securityContext": {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True,
                                             "runAsNonRoot": True, "runAsUser": 10001,
                                             "capabilities": {"drop": ["ALL"]}},
                         "resources": {"limits": {"cpu": "200m", "memory": "256Mi"},
                                       "requests": {"cpu": "100m", "memory": "128Mi"}}}]}}

def seed_role(ns, kind="Role"):
    m = {"name": "seed-role"}
    if kind == "Role": m["namespace"] = ns
    return {"apiVersion": "rbac.authorization.k8s.io/v1", "kind": kind, "metadata": m,
            "rules": [{"apiGroups": [""], "resources": ["pods", "services"], "verbs": ["get", "list", "watch"]}]}

C = lambda m: m["spec"]["containers"][0]
SC = lambda m: C(m)["securityContext"]

# (id, label, function, expected) - workload operators. Operators in the same
# `group` are mutually exclusive and are never composed together.
WL = []
def op(group, oid, label, expected="deny"):
    def deco(fn): WL.append((group, oid, label, fn, expected)); return fn
    return deco

@op("user", "run_as_root", "PSS: runAsUser 0 / runAsNonRoot false")
def _(m): SC(m)["runAsUser"] = 0; SC(m)["runAsNonRoot"] = False
@op("priv", "privileged", "PSS: privileged container")
def _(m): SC(m)["privileged"] = True
@op("esc", "allow_priv_esc", "PSS: allowPrivilegeEscalation true")
def _(m): SC(m)["allowPrivilegeEscalation"] = True
@op("hostnet", "host_network", "PSS: hostNetwork")
def _(m): m["spec"]["hostNetwork"] = True
@op("hostpid", "host_pid", "PSS: hostPID")
def _(m): m["spec"]["hostPID"] = True
@op("hostipc", "host_ipc", "PSS: hostIPC")
def _(m): m["spec"]["hostIPC"] = True
for path in ("/", "/var/run/docker.sock", "/etc"):
    @op("hostpath", f"hostpath_{path.strip('/').replace('/', '_') or 'root'}", f"PSS: hostPath {path}")
    def _(m, path=path):
        m["spec"]["volumes"] = [{"name": "h", "hostPath": {"path": path}}]
        C(m)["volumeMounts"] = [{"name": "h", "mountPath": "/host"}]
for cap in ("SYS_ADMIN", "NET_ADMIN", "SYS_PTRACE", "NET_RAW"):
    @op("cap", f"cap_{cap.lower()}", f"PSS: add capability {cap}")
    def _(m, cap=cap): SC(m)["capabilities"]["add"] = [cap]
@op("rootfs", "writable_rootfs", "Org policy: readOnlyRootFilesystem false")
def _(m): SC(m)["readOnlyRootFilesystem"] = False
@op("seccomp", "seccomp_unconfined", "PSS: seccompProfile Unconfined")
def _(m): m["spec"]["securityContext"]["seccompProfile"] = {"type": "Unconfined"}
@op("hostport", "host_port", "PSS: hostPort")
def _(m): C(m)["ports"] = [{"containerPort": 8080, "hostPort": 8080}]
@op("sa", "default_sa", "Org policy: default ServiceAccount")
def _(m): m["spec"]["serviceAccountName"] = "default"
# Resource-limit operators. Presence-only policies admit malformed-but-present
# quantities; these are the cases section 2.6 of the manuscript discusses.
@op("res", "res_strip_all", "Org policy: no resources")
def _(m): C(m)["resources"] = {}
@op("res", "res_no_limits", "Org policy: requests only, no limits")
def _(m): C(m)["resources"].pop("limits")
@op("res", "res_no_mem_limit", "Org policy: memory limit missing")
def _(m): C(m)["resources"]["limits"].pop("memory")
for q in ("500u", "0.0001", "1n"):
    @op("res", f"res_cpu_submilli_{q.replace('.', 'p')}", f"Org policy intent: sub-millicore CPU limit '{q}'")
    def _(m, q=q): C(m)["resources"]["limits"]["cpu"] = q; C(m)["resources"]["requests"]["cpu"] = q
@op("res", "res_cpu_huge", "Org policy intent: CPU limit 1000 cores")
def _(m): C(m)["resources"]["limits"]["cpu"] = "1000"

RBAC = []
for kind in ("Role", "ClusterRole"):
    for oid, label, rule in [
        ("wild_verbs", "RBAC: wildcard verbs", {"apiGroups": [""], "resources": ["pods"], "verbs": ["*"]}),
        ("wild_resources", "RBAC: wildcard resources", {"apiGroups": [""], "resources": ["*"], "verbs": ["get"]}),
        ("wild_groups", "RBAC: wildcard apiGroups", {"apiGroups": ["*"], "resources": ["pods"], "verbs": ["get"]}),
        ("secrets_read", "RBAC: secrets get/list", {"apiGroups": [""], "resources": ["secrets"], "verbs": ["get", "list"]}),
        ("pods_exec", "RBAC (transitive): create pods/exec", {"apiGroups": [""], "resources": ["pods/exec"], "verbs": ["create"]}),
        ("bind_roles", "RBAC (transitive): bind roles", {"apiGroups": ["rbac.authorization.k8s.io"], "resources": ["roles", "clusterroles"], "verbs": ["bind"]}),
        ("escalate_roles", "RBAC (transitive): escalate roles", {"apiGroups": ["rbac.authorization.k8s.io"], "resources": ["roles", "clusterroles"], "verbs": ["escalate"]}),
        ("impersonate", "RBAC (transitive): impersonate", {"apiGroups": [""], "resources": ["serviceaccounts"], "verbs": ["impersonate"]}),
    ]:
        RBAC.append((kind, f"rbac_{kind.lower()}_{oid}", label, rule))

def candidates(max_order):
    out = []
    for k in range(1, max_order + 1):
        for combo in itertools.combinations(WL, k):
            if len({g for g, *_ in combo}) < k: continue   # one operator per group
            out.append(("Pod", combo))
    for r in RBAC: out.append(("RBAC", r))
    return out

def build(cand, ns):
    kind, payload = cand
    if kind == "Pod":
        m = copy.deepcopy(seed_pod(ns))
        for _, _, _, fn, _ in payload: fn(m)
        ops = [o for _, o, _, _, _ in payload]; labels = [l for _, _, l, _, _ in payload]
        expected = "deny" if any(e == "deny" for *_, e in payload) else "admit"
    else:
        rkind, oid, label, rule = payload
        m = seed_role(ns, rkind); m["rules"].append(rule)
        ops, labels, expected = [oid], [label], "deny"
    return m, ops, labels, expected

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=100)
    ap.add_argument("--seed", type=int, required=True, help="RNG seed (record it with the results)")
    ap.add_argument("--namespace", default="hardened")
    ap.add_argument("--max-order", type=int, default=3)
    ap.add_argument("--rbac-share", type=float, default=0.25)
    ap.add_argument("--outdir", default="results/fuzzed-manifests")
    a = ap.parse_args()
    rng = random.Random(a.seed)
    cands = candidates(a.max_order)
    pods = [c for c in cands if c[0] == "Pod"]; rbac = [c for c in cands if c[0] == "RBAC"]
    n_rbac = min(len(rbac), round(a.count * a.rbac_share)); n_pod = a.count - n_rbac
    # stratify pods: every single-operator mutant first, then composed ones
    singles = [c for c in pods if len(c[1]) == 1]; multi = [c for c in pods if len(c[1]) > 1]
    rng.shuffle(singles); rng.shuffle(multi)
    chosen = (singles + multi)[:n_pod] + rng.sample(rbac, n_rbac)
    if len(chosen) < a.count: raise SystemExit(f"only {len(chosen)} distinct candidates available")
    os.makedirs(a.outdir, exist_ok=True)
    for f in os.listdir(a.outdir):
        if f.endswith(".yaml") or f in ("manifest_ground_truth.tsv", "corpus.json"): os.remove(os.path.join(a.outdir, f))
    ctl = seed_pod(a.namespace); ctl["metadata"]["name"] = "fuzz-control-seed"
    yaml.safe_dump(ctl, open(os.path.join(a.outdir, "control-seed.yaml"), "w"), sort_keys=False)
    digests, rows = set(), []
    for i, cand in enumerate(chosen, 1):
        m, ops, labels, expected = build(cand, a.namespace)
        m["metadata"]["name"] = f"fuzz-{i:04d}"
        body = json.dumps({k: v for k, v in m.items() if k != "metadata"}, sort_keys=True)
        h = hashlib.sha256((m["kind"] + body).encode()).hexdigest()[:16]
        assert h not in digests, "duplicate mutant"; digests.add(h)
        fn = f"mutant-{i:04d}.yaml"
        yaml.safe_dump(m, open(os.path.join(a.outdir, fn), "w"), sort_keys=False)
        rows.append({"file": fn, "kind": m["kind"], "order": len(ops), "operators": "+".join(ops),
                     "labels": " | ".join(labels), "expected": expected, "sha16": h})
    with open(os.path.join(a.outdir, "manifest_ground_truth.tsv"), "w") as f:
        cols = ["file", "kind", "order", "operators", "labels", "expected", "sha16"]
        f.write("\t".join(cols) + "\n")
        for r in rows: f.write("\t".join(str(r[c]) for c in cols) + "\n")
    json.dump({"seed": a.seed, "count": a.count, "namespace": a.namespace, "max_order": a.max_order,
               "candidate_space": len(cands), "distinct": len(digests)},
              open(os.path.join(a.outdir, "corpus.json"), "w"), indent=2)
    print(f"[+] {len(rows)} distinct mutants (space {len(cands)}), seed={a.seed} -> {a.outdir}")

if __name__ == "__main__":
    main()
