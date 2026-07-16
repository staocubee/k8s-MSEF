#!/bin/bash

#############################################################
# MSEF
# Build Unified Evaluation Results
#
# Combines all metric outputs into one JSON document.
#############################################################

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

METRICS="$ROOT_DIR/metrics"
RESULTS="$ROOT_DIR/results"

mkdir -p "$RESULTS"

echo "=========================================="
echo "Building Unified Evaluation Report"
echo "=========================================="

#############################################################
# Ensure Required Files Exist
#############################################################

FILES=(
    cvdr.json
    mmdr.json
    idr.json
    sdr.json
    mst.json
    tar.json
    wfdr.json
)

for FILE in "${FILES[@]}"
do
    if [ ! -f "$METRICS/$FILE" ]; then
        echo "ERROR: Missing metric file -> $FILE"
        exit 1
    fi
done

#############################################################
# Merge Everything
#############################################################

jq -n \
    --slurpfile cvdr "$METRICS/cvdr.json" \
    --slurpfile mmdr "$METRICS/mmdr.json" \
    --slurpfile idr "$METRICS/idr.json" \
    --slurpfile sdr "$METRICS/sdr.json" \
    --slurpfile mst "$METRICS/mst.json" \
    --slurpfile tar "$METRICS/tar.json" \
    --slurpfile wfdr "$METRICS/wfdr.json" \
'
{
    experiment:{

        framework:"MSEF",

        version:"1.0",

        generated_at:(now | todate)

    },

    metrics:{

        CVDR:$cvdr[0],

        MMDR:$mmdr[0],

        IDR:$idr[0],

        SDR:$sdr[0],
        
        WFDR:$wfdr[0],

        MST:$mst[0],

        TAR:$tar[0]

    }

}
' > "$RESULTS/evaluation.json"

echo
echo "Evaluation JSON Created"
echo

cat "$RESULTS/evaluation.json"

echo
echo "Saved to:"
echo "$RESULTS/evaluation.json"
echo