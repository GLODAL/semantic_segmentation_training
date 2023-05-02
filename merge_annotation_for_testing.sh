#! /bin/bash

export WORKDIR=$1
export PAT_IMG_DIR=$WORKDIR/pat_img/
export PAT_PRD_DIR=$WORKDIR/pat_prd/
export OUTPUT=$2

IFS='
'

for PAT_IMG in $(find $PAT_IMG_DIR -type f -regex ".*tif$"); do
    IFS=' '
    JSON=$(gdalinfo -json "$PAT_IMG")
    SIZE=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['size'])" | tr -d [],))
    X_SIZE=${SIZE[0]}
    Y_SIZE=${SIZE[1]}

    PAT_PRD=$PAT_PRD_DIR/$(basename "$PAT_IMG").pred.tif

    upperLeft=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['upperLeft'])" | tr -d [],))
    lowerRight=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['lowerRight'])" | tr -d [],))

    gdal_translate -q -ot Byte -a_srs EPSG:3857 -a_ullr ${upperLeft[0]} ${upperLeft[1]} ${lowerRight[0]} ${lowerRight[1]} "$PAT_PRD" "$PAT_PRD.g.tif"
done

gdalwarp -co COMPRESS=Deflate $PAT_PRD_DIR/*.g.tif $OUTPUT

exit 0
