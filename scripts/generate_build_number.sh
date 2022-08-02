#!/bin/bash

# Usage:
# ./fastlane/generate_build_number.sh
#
# Will set build number to current date and save generated build bumber to .last_build_nr file.
# If ".last_build_nr" file is present, will not generate new build number, but will use its
# content as a build number.

FILE=".last_build_nr"
BUILD_NUMBER=$(date +"%y%m%d%H%M")

if test -f "$FILE"; then
    BUILD_NUMBER=$(cat $FILE)
    echo "$BUILD_NUMBER"
    exit 0
fi

echo $BUILD_NUMBER > $FILE # save for next build

echo "$BUILD_NUMBER"
