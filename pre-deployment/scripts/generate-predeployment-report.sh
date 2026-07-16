#!/bin/bash

#############################################################
# MSEF
# Generate Final Evaluation Report
#############################################################

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

METRICS="$ROOT_DIR/metrics"

RESULTS="$ROOT_DIR/results"

JSON_DIR="$RESULTS/json"

HTML_DIR="$RESULTS/html"

mkdir -p "$JSON_DIR"
mkdir -p "$HTML_DIR"

echo "=========================================="
echo "Generating Final Report"
echo "=========================================="

#############################################################
# Copy JSON Metrics
#############################################################

cp "$METRICS"/*.json "$JSON_DIR"/

#############################################################
# Generate HTML
#############################################################

cat > "$HTML_DIR/index.html" <<EOF
<!DOCTYPE html>

<html>

<head>

<meta charset="utf-8">

<title>MSEF Pre-Deployment Report</title>

<style>

body{

font-family:Arial;

margin:40px;

background:#f5f5f5;

}

table{

border-collapse:collapse;

width:70%;

}

th,td{

border:1px solid #999;

padding:8px;

text-align:center;

}

th{

background:#333;

color:white;

}

h1{

color:#333;

}

</style>

</head>

<body>

<h1>Kubernetes MSEF</h1>

<h2>Pre-Deployment Security Evaluation</h2>

<table>

<tr>

<th>Metric</th>

<th>Trivy</th>

<th>Snyk</th>

</tr>

<tr>

<td>CVDR</td>

<td>$(jq '.trivy.score' $METRICS/cvdr.json)</td>

<td>$(jq '.snyk.score' $METRICS/cvdr.json)</td>

</tr>

<tr>

<td>MMDR</td>

<td>$(jq '.trivy.score' $METRICS/mmdr.json)</td>

<td>$(jq '.snyk.score' $METRICS/mmdr.json)</td>

</tr>

<tr>

<td>IDR</td>

<td>$(jq '.trivy.score' $METRICS/idr.json)</td>

<td>$(jq '.snyk.score' $METRICS/idr.json)</td>

</tr>

<tr>

<td>MST (sec)</td>

<td>$(jq '.trivy.mean' $METRICS/mst.json)</td>

<td>$(jq '.snyk.mean' $METRICS/mst.json)</td>

</tr>

<tr>

<td>WFDR</td>

<td>$(jq '.trivy.score' $METRICS/wfdr.json)</td>

<td>$(jq '.snyk.score' $METRICS/wfdr.json)</td>

</tr>

<tr>

<td>SDR</td>

<td>$(jq '.trivy.score' $METRICS/sdr.json)</td>

<td>$(jq '.snyk.score' $METRICS/sdr.json)</td>

</tr>

<tr>

<td>FNR</td>

<td>$(jq '.trivy.score' $METRICS/fnr.json)</td>

<td>$(jq '.snyk.score' $METRICS/fnr.json)</td>

</tr>

<tr>

<td>TAR</td>

<td colspan="2">

$(jq '.score' $METRICS/tar.json)

</td>

</tr>

</table>

<br>

Generated:

$(date)

</body>

</html>

EOF

#############################################################
# Generate Plain Text Summary
#############################################################

cat > "$RESULTS/report.txt" <<EOF

=====================================================
MSEF PRE-DEPLOYMENT SECURITY REPORT
=====================================================

CVDR : Trivy $(jq '.trivy.score' $METRICS/cvdr.json)
       Snyk  $(jq '.snyk.score' $METRICS/cvdr.json)

MMDR : Trivy $(jq '.trivy.score' $METRICS/mmdr.json)
       Snyk  $(jq '.snyk.score' $METRICS/mmdr.json)

IDR  : Trivy $(jq '.trivy.score' $METRICS/idr.json)
       Snyk  $(jq '.snyk.score' $METRICS/idr.json)

MST  : Trivy $(jq '.trivy.mean' $METRICS/mst.json)s
       Snyk  $(jq '.snyk.mean' $METRICS/mst.json)s

WFDR : Trivy $(jq '.trivy.score' $METRICS/wfdr.json)
       Snyk  $(jq '.snyk.score' $METRICS/wfdr.json)

SDR  : Trivy $(jq '.trivy.score' $METRICS/sdr.json)
       Snyk  $(jq '.snyk.score' $METRICS/sdr.json)

FNR  : Trivy $(jq '.trivy.score' $METRICS/fnr.json)
       Snyk  $(jq '.snyk.score' $METRICS/fnr.json)

TAR  : $(jq '.score' $METRICS/tar.json)

Generated:

$(date)

=====================================================

EOF

echo

echo "JSON Report : $JSON_DIR"

echo "HTML Report : $HTML_DIR/index.html"

echo "TEXT Report : $RESULTS/report.txt"

echo