#! /bin/bash

export WORKDIR=$1
export PAT_IMG_DIR=$WORKDIR/pat_img/
export PAT_PRD_DIR=$WORKDIR/pat_prd/
export ORG_IMG_TIF="$2"
export OUTPUT="$3"

IFS='
'
EPSG=$(gdalsrsinfo -o epsg "$ORG_IMG_TIF")

for PAT_IMG in $(find $PAT_IMG_DIR -type f -regex ".*tif$"); do
    IFS=' '
    JSON=$(gdalinfo -json "$PAT_IMG")
    SIZE=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['size'])" | tr -d [],))
    X_SIZE=${SIZE[0]}
    Y_SIZE=${SIZE[1]}

    PAT_PRD=$PAT_PRD_DIR/$(basename "$PAT_IMG").pred.tif

    upperLeft=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['upperLeft'])" | tr -d [],))
    lowerRight=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['lowerRight'])" | tr -d [],))

    gdal_translate -q -ot Byte -a_srs $EPSG -a_ullr ${upperLeft[0]} ${upperLeft[1]} ${lowerRight[0]} ${lowerRight[1]} "$PAT_PRD" "$PAT_PRD.g.tif"
done

JSON=$(gdalinfo -json -proj4 "$ORG_IMG_TIF")

XMIN=`echo $JSON | jq .cornerCoordinates.upperLeft[0]`
YMIN=`echo $JSON | jq .cornerCoordinates.lowerLeft[1]`
XMAX=`echo $JSON | jq .cornerCoordinates.upperRight[0]`
YMAX=`echo $JSON | jq .cornerCoordinates.upperRight[1]`

gdalwarp -co COMPRESS=Deflate -te $XMIN $YMIN $XMAX $YMAX $PAT_PRD_DIR/*.g.tif "$OUTPUT"

exit 0
