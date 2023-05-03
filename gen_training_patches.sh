#! /bin/bash

export IN_IMG_DIR=$1
export IN_ANN_DIR=$2
export PATCH_SIZE=$3
export N_PATCH=$4
export OUT_PATCH_DIR=$5

rm -rf "$OUT_PATCH_DIR"
mkdir -p "$OUT_PATCH_DIR/patch_img/img" "$OUT_PATCH_DIR/patch_ann/img"

function gen_patch() {
    IMG_TIF=$1
    IFS=' '

    JSON=$(gdalinfo -json "$IMG_TIF")
    SIZE=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['size'])" | tr -d [],))
    X_SIZE=${SIZE[0]}
    Y_SIZE=${SIZE[1]}
    ANN_TIF=$IN_ANN_DIR/$(basename "$IMG_TIF" | sed 's/\(\.[a-zA-Z]\{3\}\)$/-a\1/g')

    upperRight=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['upperRight'])" | tr -d [],))
    lowerLeft=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['lowerLeft'])" | tr -d [],))
    geoTransform=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['geoTransform'])" | tr -d [],))

    PIXEL_SIZE_X=${geoTransform[1]}
    PIXEL_SIZE_Y=$(echo ${geoTransform[5]} | tr -d "-")
    #PIXEL_SIZE_X=$RES
    #PIXEL_SIZE_Y=$RES
    PATCH_SIZE_GX=$(perl -e "print $PATCH_SIZE * $PIXEL_SIZE_X")
    PATCH_SIZE_GY=$(perl -e "print $PATCH_SIZE * $PIXEL_SIZE_Y")
    IMG_EXT="${lowerLeft[0]} ${lowerLeft[1]} ${upperRight[0]} ${upperRight[1]}"
        
    j=1
    while [ $j -le $N_PATCH ]; do
        PATCH_XMIN=$(perl -e "print ${lowerLeft[0]} + rand($X_SIZE * $PIXEL_SIZE_X - $PATCH_SIZE_GX)")
        PATCH_YMIN=$(perl -e "print ${lowerLeft[1]} + rand($Y_SIZE * $PIXEL_SIZE_Y - $PATCH_SIZE_GY)")
        PATCH_XMAX=$(perl -e "print $PATCH_XMIN + $PATCH_SIZE_GX")
        PATCH_YMAX=$(perl -e "print $PATCH_YMIN + $PATCH_SIZE_GY")

        PATCH_IMG="$OUT_PATCH_DIR/patch_img/$(basename "$IMG_TIF")-${PATCH_SIZE}-${PATCH_XMIN}_${PATCH_YMIN}.tif"
        PATCH_ANN="$OUT_PATCH_DIR/patch_ann/$(basename "$IMG_TIF")-${PATCH_SIZE}-${PATCH_XMIN}_${PATCH_YMIN}.tif"

        gdal_translate -q -projwin $PATCH_XMIN $PATCH_YMAX $PATCH_XMAX $PATCH_YMIN "$IMG_TIF" "$PATCH_IMG"
        gdal_translate -q -projwin $PATCH_XMIN $PATCH_YMAX $PATCH_XMAX $PATCH_YMIN "$ANN_TIF" "$PATCH_ANN"
        # Training data augumentation.
        for OPT in -flip -flop "-rotate 90" "-rotate 180" "-rotate 270"; do 
            convert "$PATCH_IMG" $OPT "$OUT_PATCH_DIR/patch_img/$(basename "$IMG_TIF")-${PATCH_SIZE}-${PATCH_XMIN}_${PATCH_YMIN}$(echo $OPT | sed 's/rotate //g').tif" >& /dev/null
            convert "$PATCH_ANN" $OPT "$OUT_PATCH_DIR/patch_ann/$(basename "$IMG_TIF")-${PATCH_SIZE}-${PATCH_XMIN}_${PATCH_YMIN}$(echo $OPT | sed 's/rotate //g').tif" >& /dev/null
        done
        # Ending autumentation 

        j=$(expr $j + 1)
    done

}
export -f gen_patch

IFS='
'
parallel gen_patch {} ::: $(find "$IN_IMG_DIR" -type f -iname "*.tif")
