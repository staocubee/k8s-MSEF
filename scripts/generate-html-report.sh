#!/bin/bash
set -euo pipefail

RESULTS_DIR="${RESULTS_DIR:-results}"
REPORT_FILE="$RESULTS_DIR/index.html"

mkdir -p "$RESULTS_DIR"

get_metric() {
  local metric="$1"
  local file="$2"

  if [ -f "$file" ]; then
    grep -E "^$metric[[:space:]]*=" "$file" | tail -n 1 | awk -F'= ' '{print $2}' || true
  fi
}

MBR=$(get_metric "MBR" "$RESULTS_DIR/mbr-result.txt")
SPR=$(get_metric "SPR" "$RESULTS_DIR/spr-result.txt")
RDR=$(get_metric "RDR" "$RESULTS_DIR/rdr-result.txt")
MTTD=$(get_metric "MTTD" "$RESULTS_DIR/mttd-result.txt")
FPR=$(get_metric "FPR" "$RESULTS_DIR/fpr-result.txt")

cat > "$REPORT_FILE" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Kubernetes Security Evaluation Report</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      background: #f4f6f8;
      margin: 0;
      padding: 0;
      color: #222;
    }
    header {
      background: #0f172a;
      color: white;
      padding: 24px;
      text-align: center;
    }
    .container {
      max-width: 1100px;
      margin: 30px auto;
      padding: 20px;
    }
    .summary {
      background: white;
      border-radius: 10px;
      padding: 20px;
      margin-bottom: 25px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08);
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 20px;
    }
    .card {
      background: white;
      border-radius: 10px;
      padding: 20px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08);
      border-left: 6px solid #2563eb;
    }
    .card h2 {
      margin: 0;
      font-size: 18px;
      color: #334155;
    }
    .metric {
      font-size: 34px;
      font-weight: bold;
      margin-top: 12px;
      color: #0f172a;
    }
    .label {
      font-size: 14px;
      margin-top: 8px;
      color: #64748b;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      background: white;
      margin-top: 25px;
      border-radius: 10px;
      overflow: hidden;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08);
    }
    th, td {
      padding: 14px;
      border-bottom: 1px solid #e5e7eb;
      text-align: left;
    }
    th {
      background: #1e293b;
      color: white;
    }
    footer {
      text-align: center;
      color: #64748b;
      padding: 20px;
      font-size: 13px;
    }
  </style>
</head>
<body>
  <header>
    <h1>Multi-Layer Kubernetes Security Evaluation Report</h1>
    <p>Prevention • Integrity • Detection</p>
  </header>

  <div class="container">
    <div class="summary">
      <h2>Experiment Summary</h2>
      <p>
        This report presents the measured results of the proposed multi-layer security evaluation framework
        for hardening Kubernetes in DevSecOps pipelines. The framework evaluates admission control,
        image integrity enforcement, runtime detection, detection speed, and false positive behaviour.
      </p>
      <p><strong>Generated:</strong> $(date)</p>
    </div>

    <div class="grid">
      <div class="card">
        <h2>MBR</h2>
        <div class="metric">${MBR:-N/A}</div>
        <div class="label">Manifest Blocking Rate</div>
      </div>

      <div class="card">
        <h2>SPR</h2>
        <div class="metric">${SPR:-N/A}</div>
        <div class="label">Signature Policy Rejection Rate</div>
      </div>

      <div class="card">
        <h2>RDR</h2>
        <div class="metric">${RDR:-N/A}</div>
        <div class="label">Runtime Detection Rate</div>
      </div>

      <div class="card">
        <h2>MTTD</h2>
        <div class="metric">${MTTD:-N/A}</div>
        <div class="label">Mean Time to Detect</div>
      </div>

      <div class="card">
        <h2>FPR</h2>
        <div class="metric">${FPR:-N/A}</div>
        <div class="label">False Positive Rate</div>
      </div>
    </div>

    <table>
      <thead>
        <tr>
          <th>Metric</th>
          <th>Framework Layer</th>
          <th>Meaning</th>
          <th>Result</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>MBR</td>
          <td>Prevention</td>
          <td>Measures how many insecure manifests were blocked by admission control.</td>
          <td>${MBR:-N/A}</td>
        </tr>
        <tr>
          <td>SPR</td>
          <td>Integrity</td>
          <td>Measures how many unsigned image deployments were rejected.</td>
          <td>${SPR:-N/A}</td>
        </tr>
        <tr>
          <td>RDR</td>
          <td>Detection</td>
          <td>Measures how many simulated runtime attacks were detected.</td>
          <td>${RDR:-N/A}</td>
        </tr>
        <tr>
          <td>MTTD</td>
          <td>Detection</td>
          <td>Measures how quickly runtime attacks were detected.</td>
          <td>${MTTD:-N/A}</td>
        </tr>
        <tr>
          <td>FPR</td>
          <td>Detection Quality</td>
          <td>Measures how often benign workloads generated false alerts.</td>
          <td>${FPR:-N/A}</td>
        </tr>
      </tbody>
    </table>
  </div>

  <footer>
    Kubernetes Security Evaluation Framework for DevSecOps Pipelines
  </footer>
</body>
</html>
EOF

echo "HTML report generated at: $REPORT_FILE"