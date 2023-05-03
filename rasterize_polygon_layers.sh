#! /bin/bash

export WORKDIR=`mktemp -d`
export IN_VEC_DIR=$1
export IN_IMG_DIR=$2
export OUT_ANN_DIR=$3

# set the internal field separator to a newline character
IFS='
'

# loop through all vector files in the SHPDIR directory with extensions .shp, .sqlite, and .gpkg, and merge them into a single geopackage file called merged.gpkg
for VEC in $(find "$IN_VEC_DIR" -type f | grep -e ".*\.shp" -e ".*\.sqlite" -e ".*\.gpkg"); do
  ogr2ogr -f gpkg -append -update $WORKDIR/merged.gpkg $VEC -nln merged
done

# remove the OUT_ANN_DIR directory if it exists and create a new directory with the same name
rm -rf $OUT_ANN_DIR
mkdir -p $OUT_ANN_DIR

# define a function called "rasterize" that takes an image file as input and rasterizes it
function rasterize(){
  IMG=$1
  OUTTIF="$OUT_ANN_DIR/$(basename "$IMG" | sed 's/\(\.[a-zA-Z]\{3\}\)$/-a\1/g')"
  eval $(gdalinfo "$IMG" | grep Corner -A 4 |  sed 's/^\(.*)\) (.*)$/\1/g' | sed 's/ (/=(/g; s/ //g; s/,/ /' | tail -n 4)  
  eval $(gdalinfo "$IMG" | grep "Pixel Size" | sed 's/ //g;s/,/ /g; s/-//g')
  gdal_rasterize -burn 1 -of GTiff -a_nodata 0 -ot Byte -tr ${PixelSize[0]} ${PixelSize[1]} -te ${LowerLeft[0]} ${LowerLeft[1]} ${UpperRight[0]} ${UpperRight[1]} $WORKDIR/merged.gpkg "$OUTTIF" 
} 
# export the rasterize function so that it can be called by the parallel command
export -f rasterize

# use the parallel command to call the rasterize function in parallel for all image files in the RASDIR directory with extension .tif
parallel rasterize {} ::: $(find "$IN_IMG_DIR" -type f -iname "*.tif")
