#!/bin/bash

#############################################################
# MSEF Pre-Deployment Evaluation Framework
# Normalize Scanner Results
#############################################################

set +e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SCAN_DIR="$ROOT_DIR/scans"
NORMALIZED_DIR="$ROOT_DIR/normalized"

mkdir -p "$NORMALIZED_DIR"

echo "=========================================="
echo " Normalizing Scan Results"
echo "=========================================="

#############################################################
# Helper
#############################################################

normalize_file() {

    FILE=$1

    if [ ! -f "$FILE" ]; then
        echo "{}"
        return
    fi

    if ! jq empty "$FILE" >/dev/null 2>&1; then
        echo "{}"
        return
    fi

    cat "$FILE"

}

#############################################################
# Trivy
#############################################################

echo "Normalizing Trivy..."

jq -n \
--argfile image <(normalize_file "$SCAN_DIR/trivy-image.json") \
--argfile manifests <(normalize_file "$SCAN_DIR/trivy-manifests.json") \
--argfile terraform <(normalize_file "$SCAN_DIR/trivy-terraform.json") \
--argfile secrets <(normalize_file "$SCAN_DIR/trivy-secrets.json") \
--argfile dependencies <(normalize_file "$SCAN_DIR/trivy-dependencies.json") \
'
{

scanner:"Trivy",

status:"SUCCESS",

images:

(
$image.Results // []

| map(.Vulnerabilities // [])

| flatten

| map({

id:.VulnerabilityID,

severity:.Severity

})

),

manifests:

(
$manifests.Results // []

| map(.Misconfigurations // [])

| flatten

| map({

id:.ID,

severity:.Severity

})

),

terraform:

(
$terraform.Results // []

| map(.Misconfigurations // [])

| flatten

| map({

id:.ID,

severity:.Severity

})

),

secrets:

(
$secrets.Results // []

| map(.Secrets // [])

| flatten

| map({

id:.RuleID,

severity:.Severity

})

),

dependencies:

(
$dependencies.Results // []

| map(.Vulnerabilities // [])

| flatten

| map({

id:.VulnerabilityID,

severity:.Severity

})

)

}

' > "$NORMALIZED_DIR/trivy.json"

#############################################################
# Snyk
#############################################################

echo "Normalizing Snyk..."

jq -n \
--argfile image <(normalize_file "$SCAN_DIR/snyk-image.json") \
--argfile manifests <(normalize_file "$SCAN_DIR/snyk-manifests.json") \
--argfile terraform <(normalize_file "$SCAN_DIR/snyk-terraform.json") \
--argfile secrets <(normalize_file "$SCAN_DIR/snyk-secrets.json") \
--argfile dependencies <(normalize_file "$SCAN_DIR/snyk-dependencies.json") \
'
{

scanner:"Snyk",

status:

(
if ($image.status?=="FAILED")

then "FAILED"

else "SUCCESS"

end

),

images:

(
$image.vulnerabilities // []

| map({

id:.id,

severity:.severity

})

),

manifests:

(
$image.infrastructureAsCodeIssues // []

| map({

id:.id,

severity:.severity

})

),

terraform:

(
$terraform.infrastructureAsCodeIssues // []

| map({

id:.id,

severity:.severity

})

),

secrets:

(
$secrets.findings // []

| map({

id:.id,

severity:.severity

})

),

dependencies:

(
$dependencies.vulnerabilities // []

| map({

id:.id,

severity:.severity

})

)

}

' > "$NORMALIZED_DIR/snyk.json"

#############################################################
# Summary
#############################################################

echo

echo "=========================================="

echo "Normalization Complete"

echo "=========================================="

echo

echo "Files Created"

echo

ls -1 "$NORMALIZED_DIR"

echo