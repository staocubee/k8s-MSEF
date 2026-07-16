#!/usr/bin/env bash

###############################################################################
#
# Kubernetes MSEF
# Pre-Deployment Evaluation Pipeline
#
# Executes the complete experimental workflow
#
###############################################################################

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

cd "${ROOT_DIR}"

###############################################################################
# Directories
###############################################################################

RESULT_DIR="pre-deployment/results"

mkdir -p "${RESULT_DIR}"
mkdir -p "${RESULT_DIR}/txt"
mkdir -p "${RESULT_DIR}/json"
mkdir -p "${RESULT_DIR}/html"
mkdir -p "${RESULT_DIR}/figures"
mkdir -p "${RESULT_DIR}/logs"

mkdir -p pre-deployment/scans

LOG="${RESULT_DIR}/logs/run.log"

START=$(date +%s)

echo "==================================================" | tee "${LOG}"
echo " Kubernetes MSEF Pre-Deployment Evaluation" | tee -a "${LOG}"
echo "==================================================" | tee -a "${LOG}"
echo "" | tee -a "${LOG}"

###############################################################################
# Check Dependencies
###############################################################################

echo "Checking dependencies..."

TOOLS=(
docker
jq
awk
bc
trivy
snyk
)

for tool in "${TOOLS[@]}"
do
    if ! command -v "$tool" >/dev/null 2>&1
    then
        echo "ERROR: ${tool} is not installed."
        exit 1
    fi
done

echo "Dependencies OK."

echo ""

###############################################################################
# Verify Dataset
###############################################################################

echo "Checking experiment dataset..."

REQUIRED=(
pre-deployment/test-artifacts/vulnerable-image/Dockerfile
pre-deployment/test-artifacts/vulnerable-manifests
pre-deployment/test-artifacts/vulnerable-terraform
)

for file in "${REQUIRED[@]}"
do
    if [ ! -e "$file" ]
    then
        echo "Missing dataset:"
        echo "$file"
        exit 1
    fi
done

echo "Dataset OK."

echo ""

###############################################################################
# Build Vulnerable Image
###############################################################################

echo "=================================================="
echo "Building vulnerable Docker image"
echo "=================================================="

docker build \
-t msef/vulnerable-image:latest \
pre-deployment/test-artifacts/vulnerable-image

echo ""

###############################################################################
# Execute Metrics
###############################################################################

echo "=================================================="
echo "1. CVDR"
echo "=================================================="

./pre-deployment/scripts/measure-cvdr.sh

echo ""

echo "=================================================="
echo "2. MMDR"
echo "=================================================="

./pre-deployment/scripts/measure-mmdr.sh

echo ""

echo "=================================================="
echo "3. IDR"
echo "=================================================="

./pre-deployment/scripts/measure-idr.sh

echo ""

echo "=================================================="
echo "4. MST"
echo "=================================================="

./pre-deployment/scripts/measure-mst.sh

echo ""

echo "=============================================="
echo "7. Workflow Detection Rate (WFDR)"
echo "=============================================="

./pre-deployment/scripts/measure-wfdr.sh

echo ""

echo "=================================================="
echo "4. SDR"
echo "=================================================="

./pre-deployment/scripts/measure-sdr.sh

echo ""

echo "=================================================="
echo "5. FNR"
echo "=================================================="

./pre-deployment/scripts/measure-fnr.sh

echo ""

echo "=================================================="
echo "6. TAR"
echo "=================================================="

./pre-deployment/scripts/measure-tar.sh

echo ""

#############################################################
# Generate Final Report
#############################################################

echo
echo "=================================================="
echo "Generating Final Report"
echo "=================================================="

./pre-deployment/scripts/generate-predeployment-report.sh

echo
echo "=================================================="
echo "Evaluation Completed Successfully"
echo "=================================================="

echo
echo "Reports Generated:"
echo
echo "JSON : results/json/"
echo "HTML : results/html/index.html"
echo "TEXT : results/report.txt"
echo