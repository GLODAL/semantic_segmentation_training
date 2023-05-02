#! /bin/bash

#%%script env RASDIR="$training_img" MASKDIR="$training_ann_ras" PATRASDIR="$patch_img" PATMASKDIR="$patch_ann" PATCH_SIZE="$patch_size" PATPRED="$patch_pred" TEST_RESULTS="$test_results" bash

export PAT_IMG_DIR=$1
export PAT_PRD_DIR=$2
export TEST_RESULTS=$3

IFS='
'

for IMG_EXTENDED in $(find $PAT_IMG_DIR -type f -regex ".*tif$"); do
    IFS=' '
    JSON=$(gdalinfo -json "$IMG_EXTENDED")
    SIZE=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['size'])" | tr -d [],))
    X_SIZE=${SIZE[0]}
    Y_SIZE=${SIZE[1]}

    PRED_TIF=$PAT_PRD_DIR/$(basename "$IMG_EXTENDED").pred.tif

    upperLeft=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['upperLeft'])" | tr -d [],))
    lowerRight=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['lowerRight'])" | tr -d [],))

    gdal_translate -q -ot Byte -a_srs EPSG:3857 -a_ullr ${upperLeft[0]} ${upperLeft[1]} ${lowerRight[0]} ${lowerRight[1]} "$PRED_TIF" "$TEST_RESULTS/$(basename "$PRED_TIF").g.tif"

done
