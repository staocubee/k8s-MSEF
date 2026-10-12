"""Rule-name consistency across Falco, KRE and the runtime harness. No cluster needed.
Run: python3 tests/test_rule_consistency.py"""
import json, os, sys, yaml
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = lambda *a: os.path.join(ROOT, *a)

values = yaml.safe_load(open(P("gitops/platform/dev/falco/values.yaml")))
falco_rules = {r["rule"] for r in yaml.safe_load(values["customRules"]["msef-runtime-rules.yaml"]) if "rule" in r}
cm = yaml.safe_load(open(P("gitops/platform/dev/kre/configmap.yaml")))
plans = json.loads(cm["data"]["rule-plans.json"])
rows = [l.rstrip("\n").split("\t") for l in open(P("k8s/runtime-tests/scenarios.tsv"))][1:]
tsv = {r[3]: r[4] for r in rows}
manifests_missing = [r[1] for r in rows if not os.path.exists(P("k8s/runtime-tests", r[1]))]
pod_mismatch = [r[0] for r in rows if os.path.exists(P("k8s/runtime-tests", r[1]))
                and yaml.safe_load(open(P("k8s/runtime-tests", r[1])))["metadata"]["name"] != r[2]]
dep = yaml.safe_load(open(P("gitops/platform/dev/kre/deployment.yaml")))
env = {e["name"]: e for e in dep["spec"]["template"]["spec"]["containers"][0]["env"]}
prefix = "MSEF "

checks = [
    ("Falco customRules == KRE rule-plans", falco_rules == set(plans), falco_rules ^ set(plans)),
    ("KRE rule-plans == scenarios.tsv expected rules", set(plans) == set(tsv), set(plans) ^ set(tsv)),
    ("KRE plan == scenarios.tsv expected action", all(plans.get(r) == a for r, a in tsv.items()),
     {r: (plans.get(r), a) for r, a in tsv.items() if plans.get(r) != a}),
    ("all rule names carry the KRE prefix", all(r.startswith(prefix) for r in plans), [r for r in plans if not r.startswith(prefix)]),
    ("every scenario manifest exists", not manifests_missing, manifests_missing),
    ("scenario pod names match scenarios.tsv", not pod_mismatch, pod_mismatch),
    ("deployment injects KRE_RULE_PLANS from kre-config",
     env.get("KRE_RULE_PLANS", {}).get("valueFrom", {}).get("configMapKeyRef", {}) == {"name": "kre-config", "key": "rule-plans.json"}, None),
    ("kre-config is in the KRE kustomization", "configmap.yaml" in open(P("gitops/platform/dev/kre/kustomization.yaml")).read(), None),
]
bad = 0
for name, ok, detail in checks:
    print(("PASS" if ok else "FAIL"), name, "" if ok else f"-> {detail}"); bad += not ok
print(f"\n{len(checks) - bad}/{len(checks)} passed"); sys.exit(1 if bad else 0)
