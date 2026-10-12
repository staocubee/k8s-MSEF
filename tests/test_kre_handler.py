"""Offline tests for the KRE controller against an in-memory fake Kubernetes API.
Run: python3 tests/test_kre_handler.py   (no cluster required)"""
import importlib.util, json, os, sys, tempfile, threading, time, types

class ApiException(Exception):
    def __init__(self, status=500, reason=""): self.status, self.reason, self.body = status, reason, ""

class O:  # attribute bag
    def __init__(self, **kw): self.__dict__.update(kw)

STATE = {}
def reset():
    STATE.clear()
    STATE.update(pods={("hardened", "token-theft"): O(metadata=O(uid="uid-1", labels={"app": "token-theft"}),
                                                   spec=O(service_account_name="msef-attack-sa"))},
                 netpols={}, rbs={("hardened", "msef-attack-sa-probe"): O(metadata=O(name="msef-attack-sa-probe"),
                         role_ref=O(name="msef-attack-probe"), subjects=[O(kind="ServiceAccount", name="msef-attack-sa", namespace="hardened")])},
                 calls=[])

class Core:
    def read_namespaced_pod(self, name, namespace):
        p = STATE["pods"].get((namespace, name))
        if not p: raise ApiException(404, "NotFound")
        return p
    def patch_namespaced_pod(self, name, namespace, body):
        self.read_namespaced_pod(name, namespace).metadata.labels.update(body["metadata"]["labels"]); STATE["calls"].append("patch")
    def delete_namespaced_pod(self, name, namespace, grace_period_seconds=0):
        if (namespace, name) not in STATE["pods"]: raise ApiException(404, "NotFound")
        del STATE["pods"][(namespace, name)]; STATE["calls"].append("delete_pod")
class Net:
    def create_namespaced_network_policy(self, namespace, body):
        STATE["netpols"][(namespace, body.metadata.name)] = body; STATE["calls"].append("netpol")
    def read_namespaced_network_policy(self, name, namespace):
        if (namespace, name) not in STATE["netpols"]: raise ApiException(404)
class Rbac:
    def list_namespaced_role_binding(self, ns): return O(items=[v for (n, _), v in STATE["rbs"].items() if n == ns])
    def delete_namespaced_role_binding(self, name, ns): del STATE["rbs"][(ns, name)]; STATE["calls"].append("delete_rb")
    def list_cluster_role_binding(self): return O(items=[])
    def create_namespaced_role_binding(self, *a, **k): raise AssertionError("KRE must never create bindings")

def install_fake():
    k = types.ModuleType("kubernetes"); c = types.ModuleType("kubernetes.client"); cfg = types.ModuleType("kubernetes.config")
    rest = types.ModuleType("kubernetes.client.rest"); rest.ApiException = ApiException
    c.CoreV1Api, c.NetworkingV1Api, c.RbacAuthorizationV1Api = Core, Net, Rbac
    for n in ("V1NetworkPolicy", "V1ObjectMeta", "V1NetworkPolicySpec", "V1LabelSelector"): setattr(c, n, lambda **kw: O(**kw))
    cfg.load_incluster_config = lambda: None; cfg.load_kube_config = lambda: None
    k.client, k.config, c.rest = c, cfg, rest
    sys.modules.update({"kubernetes": k, "kubernetes.client": c, "kubernetes.config": cfg, "kubernetes.client.rest": rest})

import yaml
_CM = os.path.join(os.path.dirname(__file__), "..", "gitops", "platform", "dev", "kre", "configmap.yaml")
RULE_PLANS = yaml.safe_load(open(_CM))["data"]["rule-plans.json"]   # the real ConfigMap content
BASE_ENV = {"KRE_QUEUE_MAXSIZE": "10000", "KRE_WORKER_THREADS": "4", "KRE_DEBOUNCE_WINDOW": "3.0",
            "KRE_RULE_PLANS": RULE_PLANS}

def load(env):
    os.environ.update({**BASE_ENV, **env}); install_fake()
    path = os.path.join(os.path.dirname(__file__), "..", "gitops", "platform", "dev", "kre", "msef-kre-handler.py")
    spec = importlib.util.spec_from_file_location(f"kre_{time.time_ns()}", path); m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m); return m

def alert(rule, ns="hardened", pod="token-theft"):
    return {"rule": rule, "time": "2026-10-12T10:00:00.000000000Z", "output_fields": {"k8s.ns.name": ns, "k8s.pod.name": pod}}

def records(path): return [json.loads(l) for l in open(path)] if os.path.exists(path) else []

def run():
    results = []
    def check(name, cond): results.append((name, bool(cond))); print(("PASS" if cond else "FAIL"), name)
    with tempfile.TemporaryDirectory() as d:
        # ---- async mode
        reset(); log = os.path.join(d, "a.jsonl")
        m = load({"KRE_MODE": "async", "KRE_AUDIT_LOG": log, "KRE_WORKER_THREADS": "2", "KRE_CONFIRM_POLL": "0.01"})
        cl = m.app.test_client()
        r = cl.post("/remediate", json=alert("MSEF Service Account Token Access"))
        check("async: /remediate returns 202", r.status_code == 202)
        r2 = cl.post("/remediate", json=alert("MSEF Service Account Token Access"))
        check("async: duplicate within window is debounced (200)", r2.status_code == 200 and r2.json["status"] == "debounced")
        check("out-of-scope namespace is not remediated", cl.post("/remediate", json=alert("MSEF Service Account Token Access", ns="kube-system", pod="kube-dns-x")).json["status"] == "out_of_scope")
        r_un = cl.post("/remediate", json=alert("MSEF Rule Not In ConfigMap", pod="token-theft"))
        check("MSEF-prefixed rule absent from ConfigMap is not remediated", r_un.status_code == 202)
        check("non-MSEF Falco rule is ignored", cl.post("/remediate", json=alert("Terminal shell in container")).json["status"] == "ignored")
        m.event_queue.join(); time.sleep(0.05)
        recs = records(log); proc = [x for x in recs if x["status"] == "processed"]
        unsup = [x for x in recs if x["status"] == "unsupported_rule"]
        check("unknown rule audited as unsupported, success=false, no action", len(unsup) == 1 and unsup[0]["success"] is False and not unsup[0].get("actions"))
        check("exactly one processed record", len(proc) == 1)
        p = proc[0] if proc else {}
        check("token plan = quarantine + revoke + terminate", p.get("action_taken") == "QUARANTINE_REVOKE_TERMINATE")
        check("containment confirmed, success=true", p.get("success") is True and p.get("t_confirmed") is not None)
        check("MTTC = t_confirmed - t_received (>= queue wait)", p.get("mttc_seconds") is not None and p["mttc_seconds"] >= p["queue_wait_seconds"])
        check("revocation deleted the attack RoleBinding", ("hardened", "msef-attack-sa-probe") not in STATE["rbs"])
        check("quarantine policy selects unique per-pod label", any(np.spec.pod_selector.match_labels == {m.QUARANTINE_LABEL: "uid-1"} for np in STATE["netpols"].values()))
        check("every alert audited (processed+debounced+out_of_scope+ignored)", sorted(x["status"] for x in recs) == sorted(["processed", "debounced", "out_of_scope", "ignored_non_msef_rule", "unsupported_rule"]))
        # ---- startup must fail without a rule map
        import subprocess
        code = ("import os,sys;sys.path.insert(0,'tests');import test_kre_handler as T;"
                "os.environ.pop('KRE_RULE_PLANS',None);T.BASE_ENV.pop('KRE_RULE_PLANS');T.reset();T.load({})")
        pr = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True, cwd=os.path.join(os.path.dirname(__file__), ".."))
        check("KRE refuses to start without KRE_RULE_PLANS", pr.returncode != 0 and "KRE_RULE_PLANS is not set" in (pr.stderr + pr.stdout))
        # ---- every ConfigMap rule produces its plan (one pod per rule, sync mode)
        reset(); logp = os.path.join(d, "p.jsonl"); plans = json.loads(RULE_PLANS)
        for i, rule in enumerate(plans):
            STATE["pods"][("hardened", f"r{i}")] = O(metadata=O(uid=f"ur{i}", labels={}), spec=O(service_account_name="msef-attack-sa"))
        mp = load({"KRE_MODE": "sync", "KRE_AUDIT_LOG": logp, "KRE_CONFIRM_POLL": "0.01"})
        cp = mp.app.test_client()
        for i, rule in enumerate(plans): cp.post("/remediate", json=alert(rule, pod=f"r{i}"))
        got = {x["falco_rule"]: (x["action_taken"], x["success"]) for x in records(logp)}
        check(f"all {len(plans)} ConfigMap rules -> configured plan, contained", got == {r: (p, True) for r, p in plans.items()})
        # ---- sync mode
        reset(); log2 = os.path.join(d, "s.jsonl")
        m2 = load({"KRE_MODE": "sync", "KRE_AUDIT_LOG": log2, "KRE_CONFIRM_POLL": "0.01"})
        r = m2.app.test_client().post("/remediate", json=alert("MSEF Interactive Shell Execution"))
        check("sync: returns 200 after containment", r.status_code == 200 and r.json["status"] == "contained")
        check("sync: record written with kre_mode=sync", records(log2) and records(log2)[0]["kre_mode"] == "sync")
        # ---- queue saturation (no workers, queue of 1)
        reset(); log3 = os.path.join(d, "q.jsonl")
        m3 = load({"KRE_MODE": "async", "KRE_AUDIT_LOG": log3, "KRE_WORKER_THREADS": "0", "KRE_QUEUE_MAXSIZE": "1"})
        c3 = m3.app.test_client()
        c3.post("/remediate", json=alert("MSEF Outbound C2 Connection", pod="a"))
        r = c3.post("/remediate", json=alert("MSEF Outbound C2 Connection", pod="b"))
        check("queue full -> 503 and audited as dropped", r.status_code == 503 and any(x["status"] == "dropped_queue_full" for x in records(log3)))
        # ---- concurrency: 50 distinct pods, no lost events
        reset(); log4 = os.path.join(d, "c.jsonl")
        for i in range(50):
            STATE["pods"][("hardened", f"p{i}")] = O(metadata=O(uid=f"u{i}", labels={}), spec=O(service_account_name="sa"))
        m4 = load({"KRE_MODE": "async", "KRE_AUDIT_LOG": log4, "KRE_WORKER_THREADS": "4", "KRE_CONFIRM_POLL": "0.01"})
        c4 = m4.app.test_client()
        ths = [threading.Thread(target=lambda i=i: c4.post("/remediate", json=alert("MSEF Outbound C2 Connection", pod=f"p{i}"))) for i in range(50)]
        [t.start() for t in ths]; [t.join() for t in ths]; m4.event_queue.join(); time.sleep(0.05)
        proc = [x for x in records(log4) if x["status"] == "processed"]
        check("50 concurrent alerts -> 50 processed, all successful", len(proc) == 50 and all(x["success"] for x in proc))
        check("no duplicate processing", len({x["target_pod"] for x in proc}) == 50)
    failed = [n for n, ok in results if not ok]
    print(f"\n{len(results) - len(failed)}/{len(results)} passed"); sys.exit(1 if failed else 0)

if __name__ == "__main__":
    run()
