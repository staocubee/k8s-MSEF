#!/usr/bin/env bash

###############################################################################
# Kubernetes Library
###############################################################################

namespace_exists() {

    kubectl get ns "$1" >/dev/null 2>&1

}

resource_exists() {

    kubectl get "$1" "$2" >/dev/null 2>&1

}

crd_exists() {

    kubectl get crd "$1" >/dev/null 2>&1

}

apply_dry_run() {

    kubectl apply \
        --dry-run=server \
        -f "$1" \
        ${2:+-n "$2"} \
        2>&1

}

apply_manifest() {

    kubectl apply \
        -f "$1" \
        ${2:+-n "$2"}

}

delete_manifest() {

    kubectl delete \
        -f "$1" \
        --ignore-not-found \
        ${2:+-n "$2"} \
        >/dev/null 2>&1

}

wait_for_pod() {

    kubectl wait \
        --for=condition=Ready \
        pod/"$1" \
        -n "$2" \
        --timeout="${3:-60s}" \
        >/dev/null 2>&1

}

pod_logs() {

    kubectl logs "$1" -n "$2" 2>/dev/null || true

}

pod_exec() {

    kubectl exec \
        -n "$2" \
        "$1" \
        -- "${@:3}"

}

admission_blocked() {

    local output="$1"

    echo "$output" | grep -Eiq \
    "denied|forbidden|violation|failed|disallowed|required|policy"
}