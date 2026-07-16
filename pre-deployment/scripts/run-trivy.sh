#!/bin/bash

#############################################################
# MSEF Pre-Deployment Evaluation Framework
# Trivy Scanner
#############################################################

set +e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ARTIFACTS="$ROOT_DIR/test-artifacts"
SCANS="$ROOT_DIR/scans"
TIMINGS="$ROOT_DIR/timings"

mkdir -p "$SCANS"
mkdir -p "$TIMINGS"

echo "=========================================="
echo "Running Trivy Scans"
echo "=========================================="

#############################################
# Helper
#############################################

measure_scan() {

NAME=$1
OUTPUT=$2
shift 2

START=$(date +%s)

"$@"

END=$(date +%s)

ELAPSED=$((END-START))

eval "${NAME}_TIME=$ELAPSED"

}

#############################################
# 1 Image
#############################################

echo
echo "[1/6] Image Scan"

measure_scan IMAGE \
"$SCANS/trivy-image.json" \
trivy image \
--quiet \
--format json \
-o "$SCANS/trivy-image.json" \
msef/vulnerable-image:latest

#############################################
# 2 Kubernetes
#############################################

echo
echo "[2/6] Kubernetes Manifest Scan"

measure_scan MANIFEST \
"$SCANS/trivy-manifests.json" \
trivy config \
--quiet \
--format json \
-o "$SCANS/trivy-manifests.json" \
"$ARTIFACTS/vulnerable-manifests"

#############################################
# 3 Terraform
#############################################

echo
echo "[3/6] Terraform Scan"

measure_scan TERRAFORM \
"$SCANS/trivy-terraform.json" \
trivy config \
--quiet \
--format json \
-o "$SCANS/trivy-terraform.json" \
"$ARTIFACTS/vulnerable-terraform"

#############################################
# 4 Secrets
#############################################

echo
echo "[4/6] Secret Scan"

measure_scan SECRET \
"$SCANS/trivy-secrets.json" \
trivy fs \
--quiet \
--format json \
-o "$SCANS/trivy-secrets.json" \
"$ARTIFACTS/vulnerable-secrets"

#############################################
# 5 Dependencies
#############################################

echo
echo "[5/6] Dependency Scan"

measure_scan DEPENDENCY \
"$SCANS/trivy-dependencies.json" \
trivy fs \
--quiet \
--format json \
-o "$SCANS/trivy-dependencies.json" \
"$ARTIFACTS/vulnerable-dependencies"

#############################################
# 6 Workflow
#############################################

echo
echo "[6/6] GitHub Actions Workflow Scan"

measure_scan WORKFLOW \
"$SCANS/trivy-workflow.json" \
trivy config \
--quiet \
--format json \
-o "$SCANS/trivy-workflow.json" \
"$ARTIFACTS/vulnerable-workflow"

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

cat > "$TIMINGS/trivy-times.json" <<EOF
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
echo "Trivy Scan Complete"
echo "=========================================="

cat "$TIMINGS/trivy-times.json"

echo