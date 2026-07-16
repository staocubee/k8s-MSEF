#!/bin/bash

#############################################################
# MSEF Pre-Deployment Evaluation Framework
# Snyk Scanner
#############################################################

set +e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ARTIFACTS="$ROOT_DIR/test-artifacts"
SCANS="$ROOT_DIR/scans"
TIMINGS="$ROOT_DIR/timings"

mkdir -p "$SCANS"
mkdir -p "$TIMINGS"

echo "=========================================="
echo "Running Snyk Scans"
echo "=========================================="

#############################################
# Helper Function
#############################################

measure_scan() {

NAME=$1
shift

START=$(date +%s)

"$@"

END=$(date +%s)

ELAPSED=$((END-START))

eval "${NAME}_TIME=$ELAPSED"

}

#############################################
# 1 Image Scan
#############################################

echo
echo "[1/6] Image Scan"

measure_scan IMAGE \
snyk container test \
msef/vulnerable-image:latest \
--json-file-output="$SCANS/snyk-image.json"

#############################################
# 2 Kubernetes Manifest Scan
#############################################

echo
echo "[2/6] Kubernetes Manifest Scan"

measure_scan MANIFEST \
snyk iac test \
"$ARTIFACTS/vulnerable-manifests" \
--json-file-output="$SCANS/snyk-manifests.json"

#############################################
# 3 Terraform Scan
#############################################

echo
echo "[3/6] Terraform Scan"

measure_scan TERRAFORM \
snyk iac test \
"$ARTIFACTS/vulnerable-terraform" \
--json-file-output="$SCANS/snyk-terraform.json"

#############################################
# 4 Secret Scan
#############################################

echo
echo "[4/6] Secret Scan"

measure_scan SECRET \
snyk code test \
"$ARTIFACTS/vulnerable-secrets" \
--json-file-output="$SCANS/snyk-secrets.json"

#############################################
# 5 Dependency Scan
#############################################

echo
echo "[5/6] Dependency Scan"

measure_scan DEPENDENCY \
snyk test \
"$ARTIFACTS/vulnerable-dependencies" \
--json-file-output="$SCANS/snyk-dependencies.json"

#############################################
# 6 GitHub Actions Workflow Scan
#############################################

echo
echo "[6/6] GitHub Workflow Scan"

measure_scan WORKFLOW \
snyk iac test \
"$ARTIFACTS/vulnerable-workflow" \
--json-file-output="$SCANS/snyk-workflow.json"

#############################################
# Total
#############################################

TOTAL=$((

IMAGE_TIME +

MANIFEST_TIME +

TERRAFORM_TIME +

SECRET_TIME +

DEPENDENCY_TIME +

WORKFLOW_TIME

))

#############################################
# Timing JSON
#############################################

cat > "$TIMINGS/snyk-times.json" <<EOF
{
  "image": $IMAGE_TIME,
  "manifest": $MANIFEST_TIME,
  "terraform": $TERRAFORM_TIME,
  "secret": $SECRET_TIME,
  "dependency": $DEPENDENCY_TIME,
  "workflow": $WORKFLOW_TIME,
  "total": $TOTAL
}
EOF

echo
echo "=========================================="
echo "Snyk Scan Complete"
echo "=========================================="

cat "$TIMINGS/snyk-times.json"

echo