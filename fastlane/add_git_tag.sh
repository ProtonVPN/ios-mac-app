#!/bin/bash


# ios/beta/2.4.1-2105271204

APP_OS="ios"
VERSION_NUMBER=`grep -E "IOS_APP_VERSION" apps/ios/Config.xcconfig | grep -Eo "([0-9]+\.[0-9]+\.[0-9]+)"`
BUILD_NUMBER=`cat .last_build_nr`
GIT_TAG_NAME="$APP_OS/beta/$VERSION_NUMBER-$BUILD_NUMBER"
echo $GIT_TAG_NAME

git tag $GIT_TAG_NAME
git push origin $GIT_TAG_NAME
