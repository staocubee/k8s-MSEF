#!/usr/bin/env bash

###############################################################################
# JSON helper library
###############################################################################

set -euo pipefail

json_score() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi

    jq -r '.score' "$file"
}

json_value() {
    local file="$1"
    local key="$2"

    if [[ ! -f "$file" ]]; then
        echo ""
        return
    fi

    jq -r ".$key" "$file"
}