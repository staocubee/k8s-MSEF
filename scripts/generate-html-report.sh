#!/bin/bash
###############################################################################
#
# Multi-Layer Security Evaluation Framework (MSEF)
#
# HTML Security Report Generator
#
# Output:
# results/index.html
#
###############################################################################

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

###############################################################################
# Directories
###############################################################################

RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results}"
JSON_DIR="${RESULTS_DIR}/json"

REPORT="${RESULTS_DIR}/index.html"

mkdir -p "$RESULTS_DIR"

###############################################################################
# Read JSON helper
###############################################################################

read_json_value () {

    FILE="$1"
    KEY="$2"

    if [[ ! -f "$FILE" ]]; then
        echo "N/A"
        return
    fi

    grep "\"$KEY\"" "$FILE" \
        | head -1 \
        | awk -F':' '{print $2}' \
        | tr -d ' ,"'
}

###############################################################################
# Load Prevention Metrics
###############################################################################

MBR=$(read_json_value "$JSON_DIR/mbr.json" score)

NPER=$(read_json_value "$JSON_DIR/nper.json" score)

SMER=$(read_json_value "$JSON_DIR/smer.json" score)

PES=$(read_json_value "$JSON_DIR/pes.json" score)

###############################################################################
# Load Integrity Metrics
###############################################################################

SPR=$(read_json_value "$JSON_DIR/spr.json" score)

IES=$(read_json_value "$JSON_DIR/ies.json" score)

###############################################################################
# Load Detection Metrics
###############################################################################

RDR=$(read_json_value "$JSON_DIR/rdr.json" score)

MTTD=$(read_json_value "$JSON_DIR/mttd.json" score)

FPR=$(read_json_value "$JSON_DIR/fpr.json" score)

RRSR=$(read_json_value "$JSON_DIR/rrsr.json" score)

DES=$(read_json_value "$JSON_DIR/des.json" score)

###############################################################################
# Overall Framework Score
###############################################################################

OVERALL=$(awk \
-v p="$PES" \
-v i="$IES" \
-v d="$DES" \
'BEGIN{
printf "%.2f",(p+i+d)/3
}')

###############################################################################
# Framework Rating
###############################################################################

framework_rating () {

    VALUE="$1"

    awk -v v="$VALUE" '

    BEGIN{

        if(v>=0.95)
            print "Excellent"

        else if(v>=0.85)
            print "Very Good"

        else if(v>=0.70)
            print "Good"

        else if(v>=0.50)
            print "Fair"

        else
            print "Poor"

    }'
}

OVERALL_STATUS=$(framework_rating "$OVERALL")

###############################################################################
# Start HTML
###############################################################################

cat > "$REPORT" <<EOF
<!DOCTYPE html>

<html lang="en">

<head>

<meta charset="UTF-8">

<title>Multi-Layer Security Evaluation Framework Report</title>

<style>

*{
    box-sizing:border-box;
}

body{

    margin:0;
    padding:0;

    font-family:
    "Segoe UI",
    Arial,
    sans-serif;

    background:#f4f7fb;

    color:#1e293b;

}

header{

    background:#0f172a;

    color:white;

    padding:40px;

    text-align:center;

}

header h1{

    margin:0;

    font-size:36px;

}

header p{

    margin-top:10px;

    font-size:18px;

}

.container{

    width:92%;

    margin:auto;

    padding:30px;

}

.section{

    background:white;

    border-radius:12px;

    padding:25px;

    margin-bottom:30px;

    box-shadow:
    0 3px 10px rgba(0,0,0,.08);

}

.section h2{

    margin-top:0;

    color:#0f172a;

}

.cards{

    display:grid;

    grid-template-columns:
    repeat(auto-fit,minmax(230px,1fr));

    gap:20px;

    margin-top:20px;

}

.card{

    background:#ffffff;

    border-left:6px solid #2563eb;

    border-radius:8px;

    padding:18px;

    box-shadow:
    0 2px 8px rgba(0,0,0,.08);

}

.card h3{

    margin:0;

    color:#475569;

}

.metric{

    font-size:38px;

    font-weight:bold;

    margin-top:12px;

    color:#0f172a;

}

.subtitle{

    margin-top:8px;

    color:#64748b;

}

.summary{

    display:grid;

    grid-template-columns:
    repeat(auto-fit,minmax(300px,1fr));

    gap:20px;

}

.summary-box{

    background:#e2e8f0;

    padding:25px;

    border-radius:10px;

}

.summary-box h2{

    margin-top:0;

}

.big-score{

    font-size:56px;

    font-weight:bold;

    color:#0f172a;

}

.status{

    font-size:20px;

    font-weight:bold;

    color:#2563eb;

}

table{

    width:100%;

    border-collapse:collapse;

    margin-top:20px;

}

th{

    background:#1e293b;

    color:white;

    padding:14px;

}

td{

    padding:12px;

    border-bottom:1px solid #ddd;

}

tr:nth-child(even){

    background:#f8fafc;

}

footer{

    margin-top:40px;

    padding:30px;

    text-align:center;

    background:#0f172a;

    color:white;

}

</style>

</head>

<body>

<header>

<h1>Multi-Layer Security Evaluation Framework</h1>

<p>
Kubernetes Security Evaluation Report
</p>

</header>

<div class="container">

<div class="section">

<h2>Framework Overview</h2>

<div class="summary">

<div class="summary-box">

<h2>Overall Framework Score</h2>

<div class="big-score">
$OVERALL
</div>

<div class="status">
$OVERALL_STATUS
</div>

</div>

<div class="summary-box">

<h2>Framework Layers</h2>

<ul>

<li><b>Prevention Layer</b></li>

<li><b>Integrity Layer</b></li>

<li><b>Detection Layer</b></li>

</ul>

<p>

This report summarizes the security posture achieved by the proposed Multi-Layer Security Evaluation Framework using quantitative metrics collected from Kubernetes security experiments.

</p>

</div>

</div>

</div>

EOF

    <h2>Detailed Evaluation Results</h2>

    <table>
      <thead>
        <tr>
          <th>Layer</th>
          <th>Metric</th>
          <th>Description</th>
          <th>Result</th>
        </tr>
      </thead>

      <tbody>

        <!-- Prevention Layer -->

        <tr>
          <td rowspan="4"><strong>Prevention</strong></td>
          <td>MBR</td>
          <td>Manifest Blocking Rate</td>
          <td>${MBR:-N/A}</td>
        </tr>

        <tr>
          <td>NPER</td>
          <td>Network Policy Enforcement Rate</td>
          <td>${NPER:-N/A}</td>
        </tr>

        <tr>
          <td>SMER</td>
          <td>Secrets Management Enforcement Rate</td>
          <td>${SMER:-N/A}</td>
        </tr>

        <tr>
          <td><strong>PES</strong></td>
          <td><strong>Prevention Effectiveness Score</strong></td>
          <td><strong>${PES:-N/A}</strong></td>
        </tr>

        <!-- Integrity Layer -->

        <tr>
          <td rowspan="2"><strong>Integrity</strong></td>
          <td>SPR</td>
          <td>Supply-Chain Policy Rejection Rate</td>
          <td>${SPR:-N/A}</td>
        </tr>

        <tr>
          <td><strong>IES</strong></td>
          <td><strong>Integrity Effectiveness Score</strong></td>
          <td><strong>${IES:-N/A}</strong></td>
        </tr>

        <!-- Detection Layer -->

        <tr>
          <td rowspan="5"><strong>Detection</strong></td>
          <td>RDR</td>
          <td>Runtime Detection Rate</td>
          <td>${RDR:-N/A}</td>
        </tr>

        <tr>
          <td>MTTD</td>
          <td>Mean Time To Detect</td>
          <td>${MTTD:-N/A}</td>
        </tr>

        <tr>
          <td>FPR</td>
          <td>False Positive Rate</td>
          <td>${FPR:-N/A}</td>
        </tr>

        <tr>
          <td>RRSR</td>
          <td>Runtime Response Success Rate</td>
          <td>${RRSR:-N/A}</td>
        </tr>

        <tr>
          <td><strong>DES</strong></td>
          <td><strong>Detection Effectiveness Score</strong></td>
          <td><strong>${DES:-N/A}</strong></td>
        </tr>

      </tbody>
    </table>

    <div class="summary">

      <h2>Framework Interpretation</h2>

      <p>
      The proposed <strong>Multi-Layer Security Evaluation Framework (MSEF)</strong>
      evaluates Kubernetes security across three complementary layers.
      Rather than relying on a single security control, the framework measures
      prevention, software supply-chain integrity, and runtime detection using
      eleven quantitative metrics.
      </p>

      <ul>

        <li>
          <strong>Prevention Layer (PES)</strong><br>
          Combines Manifest Blocking Rate (MBR), Network Policy Enforcement
          Rate (NPER), and Secrets Management Enforcement Rate (SMER) to
          evaluate admission control effectiveness.
        </li>

        <li>
          <strong>Integrity Layer (IES)</strong><br>
          Measures the ability of Kyverno and Cosign to prevent deployment
          of unsigned or untrusted container images using Supply-chain
          Policy Rejection Rate (SPR).
        </li>

        <li>
          <strong>Detection Layer (DES)</strong><br>
          Evaluates runtime security through Runtime Detection Rate (RDR),
          Mean Time To Detect (MTTD), False Positive Rate (FPR),
          and Runtime Response Success Rate (RRSR).
        </li>

      </ul>

      <p>

      Together, PES, IES and DES provide an objective measurement of
      Kubernetes security posture and demonstrate how integrating
      prevention, integrity verification and runtime monitoring produces
      stronger protection than relying on any individual security control.

      </p>

    </div>
    ###############################################################################
# Final Sections
###############################################################################

cat >> "$REPORT" <<EOF

<div class="section">

<h2>Overall Framework Evaluation</h2>

<div class="cards">

<div class="card">

<h3>Prevention Layer</h3>

<div class="metric">$PES</div>

<div class="subtitle">
Manifest Security • Network Security • Secrets Management
</div>

</div>

<div class="card">

<h3>Integrity Layer</h3>

<div class="metric">$IES</div>

<div class="subtitle">
Supply-chain Integrity • Image Signature Verification
</div>

</div>

<div class="card">

<h3>Detection Layer</h3>

<div class="metric">$DES</div>

<div class="subtitle">
Runtime Detection • Response • Monitoring
</div>

</div>

</div>

<p style="margin-top:25px; line-height:1.7;">

The proposed Multi-Layer Security Evaluation Framework (MSEF)
demonstrates that Kubernetes security is most effective when
preventive controls, software supply-chain integrity verification,
and runtime detection are integrated into a single DevSecOps
security model.

Rather than evaluating isolated security tools,
the framework quantitatively measures security posture across
the complete Kubernetes deployment lifecycle using eleven
security metrics and three composite layer scores.

</p>

</div>



<div class="section">

<h2>Research Question Mapping</h2>

<table>

<thead>

<tr>

<th>Research Question</th>

<th>Evaluation Metrics</th>

<th>Framework Layer</th>

</tr>

</thead>

<tbody>

<tr>

<td>RQ1. What rollout misconfigurations affect Kubernetes deployments?</td>

<td>MBR, NPER, SMER</td>

<td>Prevention</td>

</tr>

<tr>

<td>RQ2. Can admission controls prevent insecure workloads before deployment?</td>

<td>MBR, PES</td>

<td>Prevention</td>

</tr>

<tr>

<td>RQ3. How effective are runtime security controls in detecting and responding to threats?</td>

<td>RDR, MTTD, FPR, RRSR</td>

<td>Detection</td>

</tr>

<tr>

<td>RQ4. How does integrating prevention, integrity and runtime detection improve Kubernetes security?</td>

<td>PES, IES, DES</td>

<td>Framework-wide</td>

</tr>

<tr>

<td>RQ5. How effective is the proposed MSEF through iterative policy refinement?</td>

<td>All Metrics</td>

<td>Framework-wide</td>

</tr>

</tbody>

</table>

</div>



<div class="section">

<h2>Framework Architecture</h2>

<pre style="font-size:16px;background:#f8fafc;padding:20px;border-radius:10px;line-height:1.8;">

                 Multi-Layer Security Evaluation Framework

                             Prevention Layer
                     ┌────────────────────────────┐
                     │ MBR │ NPER │ SMER │  PES   │
                     └────────────────────────────┘
                                   │
                                   ▼
                             Integrity Layer
                     ┌────────────────────────────┐
                     │ SPR │        IES           │
                     └────────────────────────────┘
                                   │
                                   ▼
                             Detection Layer
           ┌────────────────────────────────────────────────────┐
           │ RDR │ MTTD │ FPR │ RRSR │          DES             │
           └────────────────────────────────────────────────────┘

</pre>

</div>



<div class="section">

<h2>Experiment Information</h2>

<table>

<tr>

<th>Framework</th>

<td>Multi-Layer Security Evaluation Framework (MSEF)</td>

</tr>

<tr>

<th>Platform</th>

<td>Kubernetes</td>

</tr>

<tr>

<th>Admission Control</th>

<td>OPA Gatekeeper + Pod Security Admission</td>

</tr>

<tr>

<th>Integrity Verification</th>

<td>Kyverno + Cosign</td>

</tr>

<tr>

<th>Runtime Detection</th>

<td>Falco</td>

</tr>

<tr>

<th>Report Generated</th>

<td>$(date)</td>

</tr>

</table>

</div>

<footer>

<h3>

Multi-Layer Security Evaluation Framework (MSEF)

</h3>

<p>

A Quantitative Framework for Evaluating Kubernetes Security Across
Prevention, Integrity and Runtime Detection Layers

</p>

<p>

Generated automatically by the MSEF Evaluation Pipeline

</p>

</footer>

</div>

</body>

</html>

EOF

echo
echo "==========================================="
echo "HTML report generated successfully"
echo "==========================================="
echo
echo "Output:"
echo "  $REPORT"
echo