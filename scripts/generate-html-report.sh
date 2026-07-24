#!/usr/bin/env bash

###############################################################################
# Multi-Layer Security Evaluation Framework (MSEF)
#
# HTML Report Generator
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/json.sh"

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"
JSON_DIR="$RESULTS_DIR/json"

HTML="$RESULTS_DIR/index.html"

###############################################################################
# Read Metrics
###############################################################################

MBR=$(json_score "$JSON_DIR/mbr.json")
NPER=$(json_score "$JSON_DIR/nper.json")
SMER=$(json_score "$JSON_DIR/smer.json")
PES=$(json_score "$JSON_DIR/pes.json")

SPR=$(json_score "$JSON_DIR/spr.json")
IES=$(json_score "$JSON_DIR/ies.json")

RDR=$(json_score "$JSON_DIR/rdr.json")
MTTD=$(json_value "$JSON_DIR/mttd.json" score)
FPR=$(json_score "$JSON_DIR/fpr.json")
RRSR=$(json_score "$JSON_DIR/rrsr.json")
DES=$(json_score "$JSON_DIR/des.json")

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
color:#457b9d;
}

table{
width:100%;
border-collapse:collapse;
margin-top:15px;
margin-bottom:25px;
}

th{
background:#1d3557;
color:white;
padding:10px;
}

td{
padding:10px;
border:1px solid #ddd;
text-align:center;
}

.score{
font-size:32px;
font-weight:bold;
color:#2a9d8f;
}

.footer{
margin-top:60px;
font-size:13px;
color:#777;
text-align:center;
}

.summary{
display:flex;
justify-content:space-around;
margin-top:30px;
}

.card{
background:white;
padding:20px;
width:28%;
border-radius:10px;
box-shadow:0 2px 10px rgba(0,0,0,.1);
text-align:center;
}

</style>

</head>

<body>

<h1>Multi-Layer Security Evaluation Framework</h1>

<p><strong>Generated:</strong> $DATE</p>

<div class="summary">

<div class="card">
<h3>Prevention</h3>
<div class="score">$PES</div>
</div>

<div class="card">
<h3>Integrity</h3>
<div class="score">$IES</div>
</div>

<div class="card">
<h3>Detection</h3>
<div class="score">$DES</div>
</div>

</div>

<h2>Prevention Layer</h2>

<table>

<tr>
<th>Metric</th>
<th>Score</th>
</tr>

<tr>
<td>Manifest Blocking Rate (MBR)</td>
<td>$MBR</td>
</tr>

<tr>
<td>Network Policy Enforcement Rate (NPER)</td>
<td>$NPER</td>
</tr>

<tr>
<td>Secrets Management Enforcement Rate (SMER)</td>
<td>$SMER</td>
</tr>

<tr>
<th>Prevention Effectiveness Score (PES)</th>
<th>$PES</th>
</tr>

</table>

<h2>Integrity Layer</h2>

<table>

<tr>
<th>Metric</th>
<th>Score</th>
</tr>

<tr>
<td>Supply-chain Policy Rejection Rate (SPR)</td>
<td>$SPR</td>
</tr>

<tr>
<th>Integrity Effectiveness Score (IES)</th>
<th>$IES</th>
</tr>

</table>

<h2>Detection Layer</h2>

<table>

<tr>
<th>Metric</th>
<th>Score</th>
</tr>

<tr>
<td>Runtime Detection Rate (RDR)</td>
<td>$RDR</td>
</tr>

<tr>
<td>Mean Time To Detect (MTTD)</td>
<td>${MTTD} sec</td>
</tr>

<tr>
<td>False Positive Rate (FPR)</td>
<td>$FPR</td>
</tr>

<tr>
<td>Runtime Response Success Rate (RRSR)</td>
<td>$RRSR</td>
</tr>

<tr>
<th>Detection Effectiveness Score (DES)</th>
<th>$DES</th>
</tr>

</table>

<h2>Overall Framework Summary</h2>

<table>

<tr>
<th>Layer</th>
<th>Composite Score</th>
</tr>

<tr>
<td>Prevention</td>
<td>$PES</td>
</tr>

<tr>
<td>Integrity</td>
<td>$IES</td>
</tr>

<tr>
<td>Detection</td>
<td>$DES</td>
</tr>

</table>

<div class="footer">

Generated automatically by the Multi-Layer Security Evaluation Framework (MSEF).

</div>

</body>

</html>

EOF

echo "HTML report written to:"
echo "$HTML"