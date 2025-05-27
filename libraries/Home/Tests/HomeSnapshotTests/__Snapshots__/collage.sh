#!/bin/bash

# Directory containing images
IMAGEDIR="MapSnapshots/"
IMAGEDIR2="ConnectedCitySnapshots/"

# Output filename
OUTPUT="collageCountires.jpg"
OUTPUT2="collageCities.jpg"

# Size of each thumbnail
THUMB_WIDTH=320
THUMB_HEIGHT=568

# Number of columns (images per row)
COLUMNS=31

# Create a montage (collage)
montage "$IMAGEDIR"/*png \
  -thumbnail ${THUMB_WIDTH}x${THUMB_HEIGHT}^ \
  -gravity center \
  -extent ${THUMB_WIDTH}x${THUMB_HEIGHT} \
  -tile ${COLUMNS}x \
  -geometry +2+2 \
  "$OUTPUT"

montage "$IMAGEDIR2"/*png \
  -thumbnail ${THUMB_WIDTH}x${THUMB_HEIGHT}^ \
  -gravity center \
  -extent ${THUMB_WIDTH}x${THUMB_HEIGHT} \
  -tile ${COLUMNS}x \
  -geometry +2+2 \
  "$OUTPUT2"

echo "Collage created: $OUTPUT, $OUTPUT2"
