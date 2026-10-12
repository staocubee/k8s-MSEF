#!/usr/bin/env python3
"""
Admission-latency and resource-footprint benchmark for one cluster configuration.

Latency: end-to-end API latency of server-side dry-run Pod CREATE requests
(dry_run="All": admission runs, nothing is persisted), issued from one
long-lived client, so kubectl/process start-up is excluded. Warm-up requests
are discarded. Every request is recorded, including failures.
Server-side: apiserver_admission_webhook_admission_duration_seconds histograms
are snapshotted before and after when /metrics is readable (bucketed data).
Resources: metrics.k8s.io is sampled every --sample-interval seconds during the
run for Falco and KRE pods. Unavailable values are written as empty (null),
never as 0.

Usage: bench_admission.py --config C5 [--requests 500 --warmup 50 --concurrency 1
                                        --namespace hardened --image registry.k8s.io/pause:3.9]
"""
import argparse, csv, json, os, subprocess, threading, time, uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from kubernetes import client, config
from kubernetes.client.rest import ApiException

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def pod(ns, image, sa):
    return {"apiVersion": "v1", "kind": "Pod",
            "metadata": {"name": f"msef-bench-{uuid.uuid4().hex[:10]}", "namespace": ns, "labels": {"app": "msef-bench"}},
            "spec": {"serviceAccountName": sa, "automountServiceAccountToken": False, "restartPolicy": "Never",
                     "securityContext": {"runAsNonRoot": True, "seccompProfile": {"type": "RuntimeDefault"}},
                     "containers": [{"name": "c", "image": image,
                         "securityContext": {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True,
                                             "runAsNonRoot": True, "runAsUser": 10001, "capabilities": {"drop": ["ALL"]}},
                         "resources": {"limits": {"cpu": "50m", "memory": "64Mi"}, "requests": {"cpu": "10m", "memory": "32Mi"}}}]}}

def one(core, ns, image, sa):
    t0 = time.perf_counter(); wall = time.time()
    try:
        core.create_namespaced_pod(ns, pod(ns, image, sa), dry_run="All")
        return {"t_wall": wall, "latency_ms": (time.perf_counter() - t0) * 1000, "ok": True, "status": 201, "error": ""}
    except ApiException as e:
        return {"t_wall": wall, "latency_ms": (time.perf_counter() - t0) * 1000, "ok": False, "status": e.status,
                "error": (e.body or str(e))[:300].replace("\n", " ")}
    except Exception as e:
        return {"t_wall": wall, "latency_ms": (time.perf_counter() - t0) * 1000, "ok": False, "status": "", "error": repr(e)[:300]}

def scrape_metrics(api):
    try:
        data = api.call_api("/metrics", "GET", response_type="str", _return_http_data_only=True, _preload_content=True)
        return "\n".join(l for l in data.splitlines() if "admission" in l and ("webhook" in l or "controller" in l))
    except Exception as e:
        return f"# unavailable: {e!r}"

def sampler(stop, path, interval, kre_ns):
    co = client.CustomObjectsApi()
    with open(path, "w", newline="") as f:
        w = csv.writer(f); w.writerow(["t_wall", "namespace", "pod", "container", "cpu_millicores", "memory_mib", "note"])
        while not stop.is_set():
            for ns, sel in (("falco", "app.kubernetes.io/name=falco"), (kre_ns, "app=msef-kre-handler")):
                try:
                    items = co.list_namespaced_custom_object("metrics.k8s.io", "v1beta1", ns, "pods", label_selector=sel)["items"]
                    if not items: w.writerow([time.time(), ns, "", "", "", "", "no pods matched"])
                    for it in items:
                        for c in it["containers"]:
                            cpu, mem = c["usage"]["cpu"], c["usage"]["memory"]
                            cpu_m = float(cpu[:-1]) / 1e6 if cpu.endswith("n") else float(cpu[:-1]) / 1e3 if cpu.endswith("u") else float(cpu[:-1]) if cpu.endswith("m") else float(cpu) * 1000
                            mem_mib = float(mem[:-2]) / 1024 if mem.endswith("Ki") else float(mem[:-2]) if mem.endswith("Mi") else float(mem) / 2**20
                            w.writerow([it["timestamp"], ns, it["metadata"]["name"], c["name"], round(cpu_m, 3), round(mem_mib, 3), ""])
                except Exception as e:
                    w.writerow([time.time(), ns, "", "", "", "", f"unavailable: {type(e).__name__}"])
            f.flush(); stop.wait(interval)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True, help="configuration label, e.g. C0..C5")
    ap.add_argument("--requests", type=int, default=500); ap.add_argument("--warmup", type=int, default=50)
    ap.add_argument("--concurrency", type=int, default=1); ap.add_argument("--namespace", default="hardened")
    ap.add_argument("--image", default="registry.k8s.io/pause:3.9",
                    help="use a signed staocube/* image to include Kyverno signature verification in the path")
    ap.add_argument("--service-account", default="hardened-app-sa")
    ap.add_argument("--sample-interval", type=float, default=5.0); ap.add_argument("--kre-namespace", default="hardened")
    a = ap.parse_args()
    config.load_kube_config(); core = client.CoreV1Api(); api = client.ApiClient()
    rid = f"bench-{a.config}-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}"
    d = os.path.join(ROOT, "results", "runs", rid); os.makedirs(d)
    git = subprocess.run(["git", "-C", ROOT, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    meta = {"run_id": rid, "config": a.config, "started": datetime.now(timezone.utc).isoformat(), "git_commit": git,
            "server_version": client.VersionApi().get_code().git_version, **vars(a)}
    open(os.path.join(d, "apiserver_admission_metrics_before.txt"), "w").write(scrape_metrics(api))
    stop = threading.Event()
    th = threading.Thread(target=sampler, args=(stop, os.path.join(d, "resources.csv"), a.sample_interval, a.kre_namespace), daemon=True)
    th.start()
    for _ in range(a.warmup): one(core, a.namespace, a.image, a.service_account)
    with ThreadPoolExecutor(max_workers=a.concurrency) as ex:
        rows = list(ex.map(lambda _: one(core, a.namespace, a.image, a.service_account), range(a.requests)))
    stop.set(); th.join(timeout=a.sample_interval + 5)
    open(os.path.join(d, "apiserver_admission_metrics_after.txt"), "w").write(scrape_metrics(api))
    with open(os.path.join(d, "latencies.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["t_wall", "latency_ms", "ok", "status", "error"]); w.writeheader(); w.writerows(rows)
    meta.update(finished=datetime.now(timezone.utc).isoformat(), ok=sum(r["ok"] for r in rows), failed=sum(not r["ok"] for r in rows))
    json.dump(meta, open(os.path.join(d, "run.json"), "w"), indent=2)
    print(json.dumps(meta, indent=2))
    if meta["failed"]: print(f"[!] {meta['failed']} requests failed; see latencies.csv (they are reported, not dropped)")
    print(f"[+] {d}\n    analyse: python3 scripts/analyze_latency.py --baseline <C0 run dir> {d}")

if __name__ == "__main__":
    main()
