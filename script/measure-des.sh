#!/usr/bin/env bash

#############################################################
# Detection Effectiveness Score (DES)
#############################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"
JSON_DIR="${RESULTS_DIR}/json"
TXT_DIR="${RESULTS_DIR}/txt"

mkdir -p "$JSON_DIR" "$TXT_DIR"

RDR=$(jq '.score' "$JSON_DIR/rdr.json")
FPR=$(jq '.score' "$JSON_DIR/fpr.json")
MTTD=$(jq '.mean_time_seconds' "$JSON_DIR/mttd.json")
RRSR=$(jq '.score' "$JSON_DIR/rrsr.json")

MAX_MTTD=10

NORM_MTTD=$(awk -v t="$MTTD" -v m="$MAX_MTTD" \
'BEGIN{
v=1-(t/m)
if(v<0)v=0
printf "%.2f",v
}')

NORM_FPR=$(awk -v f="$FPR" \
'BEGIN{
printf "%.2f",1-f
}')

DES=$(awk \
-v a="$RDR" \
-v b="$NORM_FPR" \
-v c="$NORM_MTTD" \
-v d="$RRSR" \
'BEGIN{
printf "%.2f",(a+b+c+d)/4
}')

cat > "$JSON_DIR/des.json" <<EOF
{
  "metric":"DES",
  "rdr":$RDR,
  "fpr":$FPR,
  "mttd":$MTTD,
  "rrsr":$RRSR,
  "score":$DES
}
EOF

cat > "$TXT_DIR/des.txt" <<EOF
==========================================
Detection Effectiveness Score
==========================================

Runtime Detection Rate        : $RDR
False Positive Rate           : $FPR
Mean Time To Detect           : $MTTD
Runtime Response Success Rate : $RRSR

------------------------------------------

DES                           : $DES
EOF

cat "$TXT_DIR/des.txt"