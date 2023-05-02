#! /bin/bash

export WORKDIR=$(mktemp -p)

export INDIR_GTIFF=$1
export TEST_PATCH_SIZE=$2
export PAT_IMG_DIR=$3

function subset_patch_image (){
  IN_GTIFF=$1
  X=$2
  Y=$3
  XOFF=$(perl -e "print (($X - 1) * $TEST_PATCH_SIZE)")
  YOFF=$(perl -e "print (($Y - 1) * $TEST_PATCH_SIZE)")
  gdal_translate -q -srcwin $XOFF $YOFF $TEST_PATCH_SIZE $TEST_PATCH_SIZE $IN_GTIFF "$PAT_IMG_DIR/$(basename "$IN_GTIFF")-i-$X-$Y.tif"
}
export -f subset_patch_image

IFS='
'
for TIF in $(find "$INDIR_GTIFF" -type f | grep -e "\.png$" -e "\.tif$"); do
  IFS=' '
  JSON=$(gdalinfo -json "$TIF")
  SIZE=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['size'])" | tr -d [],))
  X_SIZE=${SIZE[0]}
  Y_SIZE=${SIZE[1]}
  N_PATCH_X=$(perl -e "use POSIX qw(floor ceil); print ceil($X_SIZE / $TEST_PATCH_SIZE)")
  N_PATCH_Y=$(perl -e "use POSIX qw(floor ceil); print ceil($Y_SIZE / $TEST_PATCH_SIZE)")  
  X_SIZE_EXTEND=$(expr $N_PATCH_X \* $TEST_PATCH_SIZE)
  Y_SIZE_EXTEND=$(expr $N_PATCH_Y \* $TEST_PATCH_SIZE)
  gdal_translate -q -srcwin 0 0 $X_SIZE_EXTEND $Y_SIZE_EXTEND "$TIF" $WORKDIR/$(basename "$TIF")
  IFS='
'
#  for X in $(seq 1 10); do for Y in $(seq 1 10); do subset_patch_image $WORKDIR/$(basename "$TIF") $X $Y; done; done
  parallel subset_patch_image $WORKDIR/$(basename "$TIF") {} {} ::: $(seq 1 $N_PATCH_X) ::: $(seq 1 $N_PATCH_Y)
done

rm -rf $WORKDIR