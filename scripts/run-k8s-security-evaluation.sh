#!/bin/bash
set -euo pipefail

echo "===================================="
echo "Kubernetes Security Evaluation Start"
echo "===================================="

echo ""
echo "Experiment Timestamp: $(date)"
echo ""

mkdir -p results

echo "Running MBR Experiment (Prevention Layer: Admission Control)"
scripts/measure-mbr.sh | tee results/mbr-result.txt
sleep 5

echo "Running SPR Experiment (Integrity Layer: Image Signature Enforcement)"
scripts/measure-spr.sh | tee results/spr-result.txt
sleep 5

echo "Running RDR Experiment (Detection Layer: Runtime Detection Coverage)"
scripts/measure-rdr.sh | tee results/rdr-result.txt
sleep 5

echo "Running MTTD Experiment (Detection Layer: Detection Speed)"
scripts/measure-mttd.sh | tee results/mttd-result.txt
sleep 5

echo "Running FPR Experiment (Detection Layer: Alert Noise)"
scripts/measure-fpr.sh | tee results/fpr-result.txt
sleep 5

echo "Generating Final Metrics Report"
scripts/generate-security-report.sh | tee results/final-security-report.txt

echo "Generating HTML Report"
scripts/generate-html-report.sh | tee results/html-report-result.txt
echo ""
echo "===================================="
echo "Security Evaluation Completed"
echo "===================================="