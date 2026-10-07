#!/usr/bin/env bash

###############################################################################
#
# Multi-Layer Security Evaluation Framework (MSEF)
#
# HTML Report Generator
#
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"
JSON_DIR="$RESULTS_DIR/json"

HTML="$RESULTS_DIR/index.html"

###############################################################################
# Helper
###############################################################################

score() {
    jq -r '.score' "$1"
}

percent() {
    awk -v x="$1" 'BEGIN{printf "%.0f",x*100}'
}

###############################################################################
# Read Metrics
###############################################################################

MBR=$(score "$JSON_DIR/mbr.json")
NPER=$(score "$JSON_DIR/nper.json")
SMER=$(score "$JSON_DIR/smer.json")
PES=$(score "$JSON_DIR/pes.json")

SPR=$(score "$JSON_DIR/spr.json")
IES=$(score "$JSON_DIR/ies.json")

RDR=$(score "$JSON_DIR/rdr.json")
MTTD=$(score "$JSON_DIR/mttd.json")
OFPR=$(score "$JSON_DIR/fpr.json")
RRSR=$(score "$JSON_DIR/rrsr.json")
DES=$(score "$JSON_DIR/des.json")

###############################################################################
# Inverted OFPR (Higher is Better)
###############################################################################

OFPR_INV=$(awk -v x="$OFPR" 'BEGIN{printf "%.2f",1-x}')

OFPR_INV_P=$(awk -v x="$OFPR" 'BEGIN{printf "%.0f",(1-x)*100}')

###############################################################################
# Normalized MTTD
###############################################################################

NORM_MTTD=$(jq -r '.normalized_mttd' "$JSON_DIR/des.json")

NORM_MTTD_P=$(awk -v x="$NORM_MTTD" 'BEGIN{
    printf "%.0f", x*100
}')

###############################################################################
# Percentages
###############################################################################

MBR_P=$(percent "$MBR")
NPER_P=$(percent "$NPER")
SMER_P=$(percent "$SMER")
PES_P=$(percent "$PES")

SPR_P=$(percent "$SPR")
IES_P=$(percent "$IES")

RDR_P=$(percent "$RDR")
OFPR_P=$(percent "$OFPR")
RRSR_P=$(percent "$RRSR")
DES_P=$(percent "$DES")

DATE=$(date)

###############################################################################
# HTML
###############################################################################

cat > "$HTML" <<EOF
<!DOCTYPE html>
<html lang="en">

<head>

<meta charset="UTF-8">

<title>MSEF Security Evaluation Report</title>

<style>

body{
font-family:Arial,Helvetica,sans-serif;
background:#f4f6f9;
margin:40px;
color:#333;
}

h1{
color:#1d3557;
}

h2{
margin-top:40px;
color:#1d3557;
}

table{
width:100%;
border-collapse:collapse;
margin-top:15px;
margin-bottom:35px;
background:white;
}

th{
background:#1d3557;
color:white;
padding:12px;
}

td{
padding:12px;
border:1px solid #ddd;
text-align:center;
}

.summary{
display:flex;
justify-content:space-between;
gap:20px;
margin:40px 0;
}

.card{
flex:1;
background:white;
border-radius:12px;
padding:25px;
box-shadow:0 3px 12px rgba(0,0,0,.12);
text-align:center;
}

.card h3{
margin:0;
color:#1d3557;
}

.score{
font-size:42px;
font-weight:bold;
color:#2a9d8f;
margin-top:15px;
}

.percent{
font-size:22px;
font-weight:bold;
color:#666;
margin-top:5px;
}

.footer{
margin-top:60px;
font-size:13px;
text-align:center;
color:#777;
}

</style>

</head>

<body>

<h1>Multi-Layer Security Evaluation Framework (MSEF)</h1>

<p><strong>Generated:</strong> $DATE</p>

<div class="summary">

<div class="card">
<h3>Prevention Layer</h3>
<div class="score">$PES</div>
<div class="percent">$PES_P%</div>
</div>

<div class="card">
<h3>Integrity Layer</h3>
<div class="score">$IES</div>
<div class="percent">$IES_P%</div>
</div>

<div class="card">
<h3>Detection Layer</h3>
<div class="score">$DES</div>
<div class="percent">$DES_P%</div>
</div>

</div>

<h2>Prevention Layer Metrics</h2>

<table>

<tr>
<th>Metric</th>
<th>Score</th>
<th>Percentage</th>
</tr>

<tr>
<td>Manifest Blocking Rate (MBR)</td>
<td>$MBR</td>
<td>$MBR_P%</td>
</tr>

<tr>
<td>Network Policy Enforcement Rate (NPER)</td>
<td>$NPER</td>
<td>$NPER_P%</td>
</tr>

<tr>
<td>Secrets Management Enforcement Rate (SMER)</td>
<td>$SMER</td>
<td>$SMER_P%</td>
</tr>

<tr>
<th>Prevention Effectiveness Score (PES)</th>
<th>$PES</th>
<th>$PES_P%</th>
</tr>

</table>

<h2>Integrity Layer Metrics</h2>

<table>

<tr>
<th>Metric</th>
<th>Score</th>
<th>Percentage</th>
</tr>

<tr>
<td>Supply-chain Policy Rejection Rate (SPR)</td>
<td>$SPR</td>
<td>$SPR_P%</td>
</tr>

<tr>
<th>Integrity Effectiveness Score (IES)</th>
<th>$IES</th>
<th>$IES_P%</th>
</tr>

</table>

<h2>Detection Layer Metrics</h2>

<table>

<tr>
<th>Metric</th>
<th>Score</th>
<th>Percentage</th>
</tr>

<tr>
<td>Runtime Detection Rate (RDR)</td>
<td>$RDR</td>
<td>$RDR_P%</td>
</tr>

<tr>
<td>Mean Time To Detect (MTTD)</td>
<td>${NORM_MTTD} seconds</td>
<td>$NORM_MTTD_P%</td>
</tr>

<tr>
<td>Normalized Operational False Positive Rate (OFPR)</td>
<td>$OFPR_INV</td>
<td>$OFPR_INV_P%</td>
</tr>

<tr>
<td>Runtime Response Success Rate (RRSR)</td>
<td>$RRSR</td>
<td>$RRSR_P%</td>
</tr>

<tr>
<th>Detection Effectiveness Score (DES)</th>
<th>$DES</th>
<th>$DES_P%</th>
</tr>

</table>

<h2>Overall Framework Summary</h2>

<table>

<tr>
<th>Layer</th>
<th>Score</th>
<th>Percentage</th>
</tr>

<tr>
<td>Prevention</td>
<td>$PES</td>
<td>$PES_P%</td>
</tr>

<tr>
<td>Integrity</td>
<td>$IES</td>
<td>$IES_P%</td>
</tr>

<tr>
<td>Detection</td>
<td>$DES</td>
<td>$DES_P%</td>
</tr>

</table>

<div class="footer">

Generated automatically by the Multi-Layer Security Evaluation Framework (MSEF).

</div>

</body>

</html>

EOF

echo
echo "HTML report written to:"
echo "$HTML"
echo