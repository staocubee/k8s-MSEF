#!/usr/bin/env bash

###############################################################################
# Kubernetes Library
#
# Multi-Layer Security Evaluation Framework (MSEF)
###############################################################################

set -euo pipefail

###############################################################################
# Namespace Helpers
###############################################################################

require_namespace() {

    local ns="$1"

    kubectl get namespace "$ns" >/dev/null 2>&1 || {
        echo "Namespace '$ns' not found."
        exit 1
    }
}

namespace_exists() {

    kubectl get namespace "$1" >/dev/null 2>&1
}

###############################################################################
# Resource Helpers
###############################################################################

resource_exists() {

    local kind="$1"
    local name="$2"

    kubectl get "$kind" "$name" >/dev/null 2>&1
}

crd_exists() {

    kubectl get crd "$1" >/dev/null 2>&1
}

###############################################################################
# Manifest Helpers
###############################################################################

apply_dry_run() {

    local manifest="$1"
    local namespace="${2:-}"

    if [[ -n "$namespace" ]]; then
        kubectl apply \
            --dry-run=server \
            -f "$manifest" \
            -n "$namespace" \
            2>&1
    else
        kubectl apply \
            --dry-run=server \
            -f "$manifest" \
            2>&1
    fi
}

###############################################################################
# Returns:
#   0 -> Manifest admitted
#   1 -> Manifest rejected or failed
###############################################################################

dry_run_success() {

    local manifest="$1"
    local namespace="${2:-}"

    if apply_dry_run "$manifest" "$namespace" >/dev/null
    then
        return 0
    fi

    return 1
}

###############################################################################
# Detect Gatekeeper/Kyverno admission rejection
###############################################################################

admission_blocked() {

    local output="$1"

    grep -Eiq \
        "(admission webhook|denied the request|forbidden|violation|policy violation|validation\.gatekeeper|kyverno)" \
        <<< "$output"
}

###############################################################################
# Apply/Delete Helpers
###############################################################################

apply_manifest() {

    local manifest="$1"
    local namespace="${2:-}"

    if [[ -n "$namespace" ]]; then
        kubectl apply \
            -f "$manifest" \
            -n "$namespace"
    else
        kubectl apply \
            -f "$manifest"
    fi
}

delete_manifest() {

    local manifest="$1"
    local namespace="${2:-}"

    if [[ -n "$namespace" ]]; then
        kubectl delete \
            -f "$manifest" \
            -n "$namespace" \
            --ignore-not-found \
            >/dev/null 2>&1
    else
        kubectl delete \
            -f "$manifest" \
            --ignore-not-found \
            >/dev/null 2>&1
    fi
}

###############################################################################
# Pod Helpers
###############################################################################

wait_for_pod() {

    local pod="$1"
    local namespace="$2"
    local timeout="${3:-60s}"

    kubectl wait \
        --for=condition=Ready \
        pod/"$pod" \
        -n "$namespace" \
        --timeout="$timeout" \
        >/dev/null 2>&1
}

pod_exists() {

    local pod="$1"
    local namespace="$2"

    kubectl get pod "$pod" \
        -n "$namespace" \
        >/dev/null 2>&1
}

pod_logs() {

    local pod="$1"
    local namespace="$2"

    kubectl logs \
        "$pod" \
        -n "$namespace" \
        2>/dev/null || true
}

pod_exec() {

    local pod="$1"
    local namespace="$2"

    shift 2

    kubectl exec \
        -n "$namespace" \
        "$pod" \
        -- "$@"
}

###############################################################################
# Generic Helpers
###############################################################################

kubectl_output() {

    kubectl "$@" 2>&1
}

kubectl_success() {

    kubectl "$@" >/dev/null 2>&1
}