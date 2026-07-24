#!/usr/bin/env bash

###############################################################################
# Falco Helper Library
###############################################################################

set -euo pipefail

###############################################################################
# Discover Falco pods
###############################################################################

find_falco_pods() {

    local namespace="${FALCO_NS:-falco}"

    kubectl get pods \
        -n "$namespace" \
        -l app.kubernetes.io/name=falco \
        -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' \
        2>/dev/null ||

    kubectl get pods \
        -n "$namespace" \
        -l app=falco \
        -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' \
        2>/dev/null
}

###############################################################################
# Collect recent Falco logs
###############################################################################

collect_falco_logs() {

    local namespace="${FALCO_NS:-falco}"

    local since="${1:-60s}"

    local pods

    pods=$(find_falco_pods)

    for pod in $pods
    do
        kubectl logs \
            -n "$namespace" \
            "$pod" \
            --since="$since" \
            2>/dev/null || true
    done
}

###############################################################################
# Search Falco logs
###############################################################################

falco_detected() {

    local pattern="$1"

    collect_falco_logs 60s | grep -Eiq "$pattern"
}

###############################################################################
# Measure detection time
###############################################################################

measure_detection_time() {

    local start="$1"

    local end

    end=$(date +%s)

    echo $((end-start))
}