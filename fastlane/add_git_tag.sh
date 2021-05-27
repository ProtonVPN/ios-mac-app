#!/bin/bash


APP_OS="ios"
VERSION_NUMBER=`grep -E "IOS_APP_VERSION" apps/ios/Config.xcconfig | grep -Eo "([0-9]+\.[0-9]+\.[0-9]+)"`
BUILD_NUMBER=`cat .last_build_nr`
GIT_TAG_NAME="$APP_OS/beta/$VERSION_NUMBER-$BUILD_NUMBER"
echo $GIT_TAG_NAME

git remote set-url origin "https://${GIT_CI_USERNAME}:${PRIVATE_TOKEN_GITLAB_API_PROTON_CI}@$(awk -F '@' '{print $2}' <<< "$CI_REPOSITORY_URL")";
git tag $GIT_TAG_NAME
git push origin $GIT_TAG_NAME
