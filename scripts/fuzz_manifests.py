#!/usr/bin/env python3
"""
Multi-Layer Security Evaluation Framework (MSEF)
Manifest Mutation & Adversarial Fuzzing Engine
Generates randomized and parameterized non-compliant manifests to evaluate MBR.
"""

import os
import sys
import copy
import yaml
import random
import argparse
from typing import List, Dict, Any

# ---------------------------------------------------------------------------
# Seed Template Workload
# ---------------------------------------------------------------------------
BASE_POD_SPEC = {
    "apiVersion": "v1",
    "kind": "Pod",
    "metadata": {
        "name": "base-workload",
        "namespace": "dev",
        "labels": {"app": "eval-workload"}
    },
    "spec": {
        "serviceAccountName": "workload-sa",
        "containers": [{
            "name": "workload-container",
            "image": "docker.io/library/nginx:1.25.0",
            "securityContext": {
                "allowPrivilegeEscalation": False,
                "readOnlyRootFilesystem": True,
                "runAsNonRoot": True,
                "runAsUser": 10001,
                "capabilities": {
                    "drop": ["ALL"]
                }
            },
            "resources": {
                "limits": {"cpu": "200m", "memory": "256Mi"},
                "requests": {"cpu": "100m", "memory": "128Mi"}
            }
        }]
    }
}

BASE_RBAC_SPEC = {
    "apiVersion": "rbac.authorization.k8s.io/v1",
    "kind": "Role",
    "metadata": {
        "name": "base-eval-role",
        "namespace": "dev"
    },
    "rules": [
        {
            "apiGroups": [""],
            "resources": ["pods", "services"],
            "verbs": ["get", "list", "watch"]
        }
    ]
}

# ---------------------------------------------------------------------------
# Mutation Operators
# ---------------------------------------------------------------------------
def mut_run_as_root(manifest: Dict[str, Any]) -> str:
    m = copy.deepcopy(manifest)
    sec = m["spec"]["containers"][0].setdefault("securityContext", {})
    sec["runAsNonRoot"] = False
    sec["runAsUser"] = 0
    return m, "CIS-5.2.6: Run As Root Enabled"

def mut_privileged(manifest: Dict[str, Any]) -> str:
    m = copy.deepcopy(manifest)
    sec = m["spec"]["containers"][0].setdefault("securityContext", {})
    sec["privileged"] = True
    return m, "CIS-5.2.1: Privileged Container Flag"

def mut_allow_priv_escalation(manifest: Dict[str, Any]) -> str:
    m = copy.deepcopy(manifest)
    sec = m["spec"]["containers"][0].setdefault("securityContext", {})
    sec["allowPrivilegeEscalation"] = True
    return m, "CIS-5.2.5: Allow Privilege Escalation"

def mut_host_network(manifest: Dict[str, Any]) -> str:
    m = copy.deepcopy(manifest)
    m["spec"]["hostNetwork"] = True
    return m, "CIS-5.2.4: Host Network Namespace Shared"

def mut_host_pid(manifest: Dict[str, Any]) -> str:
    m = copy.deepcopy(manifest)
    m["spec"]["hostPID"] = True
    return m, "CIS-5.2.2: Host PID Namespace Shared"

def mut_host_path_mount(manifest: Dict[str, Any]) -> str:
    m = copy.deepcopy(manifest)
    m["spec"]["volumes"] = [{
        "name": "host-root",
        "hostPath": {"path": "/"}
    }]
    m["spec"]["containers"][0].setdefault("volumeMounts", []).append({
        "name": "host-root",
        "mountPath": "/host"
    })
    return m, "CIS-5.2.7: HostPath Volume Mount to Host Root"

def mut_add_dangerous_cap(manifest: Dict[str, Any]) -> str:
    m = copy.deepcopy(manifest)
    sec = m["spec"]["containers"][0].setdefault("securityContext", {})
    caps = sec.setdefault("capabilities", {})
    caps.setdefault("add", []).append(random.choice(["SYS_ADMIN", "NET_ADMIN", "SYS_PTRACE"]))
    return m, "CIS-5.2.8: Dangerous Linux Capability Added"

def mut_writable_root_fs(manifest: Dict[str, Any]) -> str:
    m = copy.deepcopy(manifest)
    sec = m["spec"]["containers"][0].setdefault("securityContext", {})
    sec["readOnlyRootFilesystem"] = False
    return m, "CIS-5.2.9: Read-Only Root Filesystem Disabled"

def mut_strip_resource_limits(manifest: Dict[str, Any]) -> str:
    m = copy.deepcopy(manifest)
    m["spec"]["containers"][0]["resources"] = {}
    return m, "CIS-5.2.13: Missing CPU and Memory Resource Limits"

def mut_default_service_account(manifest: Dict[str, Any]) -> str:
    m = copy.deepcopy(manifest)
    m["spec"]["serviceAccountName"] = "default"
    return m, "CIS-5.1.5: Workload Bound to Default ServiceAccount"

def mut_rbac_wildcard_verbs(manifest: Dict[str, Any]) -> str:
    m = copy.deepcopy(manifest)
    m["rules"][0]["verbs"] = ["*"]
    return m, "CIS-5.1.3: RBAC Wildcard Verbs"

def mut_rbac_wildcard_resources(manifest: Dict[str, Any]) -> str:
    m = copy.deepcopy(manifest)
    m["rules"][0]["resources"] = ["*"]
    return m, "CIS-5.1.3: RBAC Wildcard Resources"

def mut_rbac_secret_access(manifest: Dict[str, Any]) -> str:
    m = copy.deepcopy(manifest)
    m["rules"].append({
        "apiGroups": [""],
        "resources": ["secrets"],
        "verbs": ["get", "list"]
    })
    return m, "CIS-5.1.2: RBAC Explicit Secret Ingress"

# Register mutation operators
WORKLOAD_MUTATORS = [
    mut_run_as_root,
    mut_privileged,
    mut_allow_priv_escalation,
    mut_host_network,
    mut_host_pid,
    mut_host_path_mount,
    mut_add_dangerous_cap,
    mut_writable_root_fs,
    mut_strip_resource_limits,
    mut_default_service_account,
]

RBAC_MUTATORS = [
    mut_rbac_wildcard_verbs,
    mut_rbac_wildcard_resources,
    mut_rbac_secret_access,
]

# ---------------------------------------------------------------------------
# Generator Execution
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Generate mutated manifest corpus for MSEF MBR testing.")
    parser.add_argument("--count", type=int, default=100, help="Total number of mutated manifests to produce.")
    parser.add_argument("--outdir", type=str, default="results/fuzzed-manifests", help="Output directory.")
    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)
    metadata_log = os.path.join(args.outdir, "manifest_ground_truth.tsv")

    print(f"[*] Generating {args.count} adversarial mutated manifests into '{args.outdir}'...")

    with open(metadata_log, "w") as meta:
        meta.write("file_name\tmanifest_type\tmutation_category\n")

        for idx in range(1, args.count + 1):
            is_rbac = (random.random() < 0.25) # 25% RBAC, 75% Workloads

            if is_rbac:
                mutator = random.choice(RBAC_MUTATORS)
                mutated_obj, category = mutator(BASE_RBAC_SPEC)
                mutated_obj["metadata"]["name"] = f"fuzzed-role-{idx}"
                filename = f"mutant-rbac-{idx:04d}.yaml"
            else:
                mutator = random.choice(WORKLOAD_MUTATORS)
                mutated_obj, category = mutator(BASE_POD_SPEC)
                mutated_obj["metadata"]["name"] = f"fuzzed-pod-{idx}"
                filename = f"mutant-pod-{idx:04d}.yaml"

            filepath = os.path.join(args.outdir, filename)
            with open(filepath, "w") as f:
                yaml.dump(mutated_obj, f, default_flow_style=False)

            meta.write(f"{filename}\t{'RBAC' if is_rbac else 'Pod'}\t{category}\n")

    print(f"[✓] Generation complete. Ground truth ledger recorded at '{metadata_log}'.")

if __name__ == "__main__":
    main()