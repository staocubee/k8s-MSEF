#!/bin/bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Generates a consolidated text report from all experiment outputs.
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"
JSON_DIR="$RESULTS_DIR/json"
TXT_DIR="$RESULTS_DIR/txt"

mkdir -p "$TXT_DIR"

REPORT="$TXT_DIR/security-evaluation-report.txt"

###############################################################################

metric () {

jq -r '.score // .average // "N/A"' "$1" 2>/dev/null || echo "N/A"

}

###############################################################################

MBR=$(metric "$JSON_DIR/mbr.json")
NPER=$(metric "$JSON_DIR/nper.json")
SMER=$(metric "$JSON_DIR/smer.json")
PES=$(metric "$JSON_DIR/pes.json")

SPR=$(metric "$JSON_DIR/spr.json")
IES=$(metric "$JSON_DIR/ies.json")

RDR=$(metric "$JSON_DIR/rdr.json")
MTTD=$(metric "$JSON_DIR/mttd.json")
FPR=$(metric "$JSON_DIR/fpr.json")
RRSR=$(metric "$JSON_DIR/rrsr.json")
DES=$(metric "$JSON_DIR/des.json")

###############################################################################

cat > "$REPORT" <<EOF
===========================================================
 Multi-Layer Security Evaluation Framework Report
===========================================================

Generated:
$(date)

-----------------------------------------------------------
PREVENTION LAYER
-----------------------------------------------------------

Manifest Blocking Rate (MBR)               : $MBR
Network Policy Enforcement Rate (NPER)     : $NPER
Secrets Management Enforcement Rate (SMER) : $SMER

Prevention Effectiveness Score (PES)       : $PES


-----------------------------------------------------------
INTEGRITY LAYER
-----------------------------------------------------------

Supply-chain Policy Rejection Rate (SPR)   : $SPR

Integrity Effectiveness Score (IES)        : $IES


-----------------------------------------------------------
DETECTION LAYER
-----------------------------------------------------------

Runtime Detection Rate (RDR)               : $RDR
Mean Time To Detect (MTTD)                 : $MTTD seconds
False Positive Rate (FPR)                  : $FPR
Runtime Response Success Rate (RRSR)       : $RRSR

Detection Effectiveness Score (DES)        : $DES


-----------------------------------------------------------
FRAMEWORK SUMMARY
-----------------------------------------------------------

Prevention Layer  : $PES
Integrity Layer   : $IES
Detection Layer   : $DES

===========================================================

EOF

cat "$REPORT"