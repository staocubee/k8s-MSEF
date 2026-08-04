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
# Collect recent Falco JSON logs
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
# Save current Falco events to a file
###############################################################################

capture_falco_events() {

    local outfile="$1"
    local since="${2:-60s}"

    collect_falco_logs "$since" > "$outfile"
}

###############################################################################
# Search Falco JSON logs
###############################################################################

falco_detected() {

    local pattern="$1"

    collect_falco_logs 60s |
    jq -r '.output // empty' |
    grep -Eiq "$pattern"
}

###############################################################################
# Search an existing Falco event file
###############################################################################

falco_detected_file() {

    local logfile="$1"
    local pattern="$2"

    jq -r '.output // empty' "$logfile" |
    grep -Eiq "$pattern"
}

###############################################################################
# Count matching events in a saved log
###############################################################################

count_falco_events() {

    local logfile="$1"
    local pattern="$2"

    jq -r '.output // empty' "$logfile" |
    grep -Ei "$pattern" |
    wc -l |
    tr -d ' '
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