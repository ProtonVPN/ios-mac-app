#!/bin/bash

# Directory containing images
IMAGEDIR="DisconnectedCountriesSnapshots/"
IMAGEDIR2="ConnectedCitiesSnapshots/"

# Output filename
OUTPUT="collageCountries.jpg"
OUTPUT2="collageCities.jpg"

# Size of each thumbnail
THUMB_WIDTH=320
THUMB_HEIGHT=568

# Number of columns (images per row)
COLUMNS_CITIES=24
COLUMNS_COUNTRIES=27

# Create a montage (collage)
montage "$IMAGEDIR"/*png \
  -thumbnail ${THUMB_WIDTH}x${THUMB_HEIGHT}^ \
  -gravity center \
  -extent ${THUMB_WIDTH}x${THUMB_HEIGHT} \
  -tile ${COLUMNS_COUNTRIES}x \
  -geometry +2+2 \
  "$OUTPUT"

montage "$IMAGEDIR2"/*png \
  -thumbnail ${THUMB_WIDTH}x${THUMB_HEIGHT}^ \
  -gravity center \
  -extent ${THUMB_WIDTH}x${THUMB_HEIGHT} \
  -tile ${COLUMNS_CITIES}x \
  -geometry +2+2 \
  "$OUTPUT2"

echo "Collage created: $OUTPUT, $OUTPUT2"
