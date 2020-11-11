#!/bin/bash

# Usage:
# ./fastlane/increment_build_number.sh
#
# Will set build number to current date and save generated build bumber to .last_build_nr file.
# If ".last_build_nr" file is present, will not generate new build number, but will use its
# content as a build number.

cd ..

FILE=.last_build_nr
BUILD_NUMBER=$(date +"%m%d%H%M")

if test -f "$FILE"; then
    BUILD_NUMBER=$(cat $FILE)
    echo "Will use build number read from file ($FILE): $BUILD_NUMBER"
fi

echo $BUILD_NUMBER > $FILE # save for next build

echo "Setting build number to: $BUILD_NUMBER"
xcrun agvtool new-version -all $BUILD_NUMBER
