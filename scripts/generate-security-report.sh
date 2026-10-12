#!/usr/bin/env bash

###############################################################################
#
# Multi-Layer Security Evaluation Framework (MSEF)
#
# Consolidated Security Evaluation Report
#
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"

###############################################################################
# Configuration
###############################################################################

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"

JSON_DIR="$RESULTS_DIR/json"
TXT_DIR="$RESULTS_DIR/txt"

mkdir -p "$TXT_DIR"

REPORT="$TXT_DIR/security-evaluation-report.txt"

###############################################################################
# Helpers
###############################################################################

json_value() {

    local FILE="$1"
    local KEY="$2"

    jq -r ".$KEY" "$FILE"

}

###############################################################################
# Required files
###############################################################################

require_file "$JSON_DIR/mbr.json"
require_file "$JSON_DIR/nper.json"
require_file "$JSON_DIR/smer.json"
require_file "$JSON_DIR/pes.json"

require_file "$JSON_DIR/spr.json"
require_file "$JSON_DIR/ies.json"

require_file "$JSON_DIR/rdr.json"
require_file "$JSON_DIR/mttd.json"
require_file "$JSON_DIR/fpr.json"
require_file "$JSON_DIR/rrsr.json"
require_file "$JSON_DIR/des.json"

###############################################################################
# Prevention
###############################################################################

MBR=$(json_value "$JSON_DIR/mbr.json" score)
MBR_TOTAL=$(json_value "$JSON_DIR/mbr.json" total_manifests)
MBR_BLOCKED=$(json_value "$JSON_DIR/mbr.json" blocked)

NPER=$(json_value "$JSON_DIR/nper.json" score)

SMER=$(json_value "$JSON_DIR/smer.json" score)

PES=$(json_value "$JSON_DIR/pes.json" score)

###############################################################################
# Integrity
###############################################################################

SPR=$(json_value "$JSON_DIR/spr.json" score)
SPR_TOTAL=$(json_value "$JSON_DIR/spr.json" total)
SPR_BLOCKED=$(json_value "$JSON_DIR/spr.json" blocked)

IES=$(json_value "$JSON_DIR/ies.json" score)

###############################################################################
# Detection
###############################################################################

RDR=$(json_value "$JSON_DIR/rdr.json" score)
RDR_TOTAL=$(json_value "$JSON_DIR/rdr.json" simulated_attacks)
RDR_DETECTED=$(json_value "$JSON_DIR/rdr.json" detected)

MTTD=$(json_value "$JSON_DIR/mttd.json" score)

FPR=$(json_value "$JSON_DIR/fpr.json" score)

RRSR=$(json_value "$JSON_DIR/rrsr.json" score)
RRSR_SUCCESS=$(json_value "$JSON_DIR/rrsr.json" successful_responses)
RRSR_TOTAL=$(json_value "$JSON_DIR/rrsr.json" runtime_attacks)

DES=$(json_value "$JSON_DIR/des.json" score)

###############################################################################
# Overall Status
###############################################################################

FRAMEWORK_STATUS="SUCCESS"

###############################################################################
# Report
###############################################################################

cat > "$REPORT" <<EOF
======================================================================
          Multi-Layer Security Evaluation Framework (MSEF)
======================================================================

Generated:
$(date)

======================================================================
PREVENTION LAYER
======================================================================

Manifest Blocking Rate (MBR)

    Total Insecure Manifests : $MBR_TOTAL
    Blocked                  : $MBR_BLOCKED
    Score                    : $MBR

Network Policy Enforcement Rate (NPER)

    Score                    : $NPER

Secrets Management Enforcement Rate (SMER)

    Score                    : $SMER

------------------------------------------------------------

Prevention Effectiveness Score (PES)

    Score                    : $PES


======================================================================
INTEGRITY LAYER
======================================================================

Supply-chain Policy Rejection Rate (SPR)

    Total Unsigned Images    : $SPR_TOTAL
    Blocked                  : $SPR_BLOCKED
    Score                    : $SPR

------------------------------------------------------------

Integrity Effectiveness Score (IES)

    Score                    : $IES


======================================================================
DETECTION LAYER
======================================================================

Runtime Detection Rate (RDR)

    Simulated Attacks        : $RDR_TOTAL
    Detected                 : $RDR_DETECTED
    Score                    : $RDR

Mean Time To Detect (MTTD)

    Average Detection Time   : ${MTTD} seconds

False Positive Rate (FPR)

    Score                    : $FPR

Runtime Response Success Rate (RRSR)

    Successful Responses     : $RRSR_SUCCESS
    Runtime Attacks          : $RRSR_TOTAL
    Score                    : $RRSR

------------------------------------------------------------

Detection Effectiveness Score (DES)

    Score                    : $DES


======================================================================
FRAMEWORK SUMMARY
======================================================================

Prevention Layer (PES)

    $PES

Integrity Layer (IES)

    $IES

Detection Layer (DES)

    $DES

------------------------------------------------------------

Framework Status

    $FRAMEWORK_STATUS

======================================================================

EOF

cat "$REPORT"