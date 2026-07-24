#!/usr/bin/env bash

###############################################################################
# Output Library
###############################################################################

write_json() {

    local file="$1"

    local content="$2"

    echo "$content" > "$file"

}

write_text() {

    local file="$1"

    local content="$2"

    echo "$content" > "$file"

}

metric_metadata() {

cat <<EOF
"framework":"Kubernetes MSEF",
"version":"1.0",
"timestamp":"$(timestamp)"
EOF

}