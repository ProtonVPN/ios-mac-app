#!/bin/bash

cd ..
commitCount=$(git rev-list --count HEAD)
buildNumber=$(expr $commitCount + 1161)
xcrun agvtool new-version -all $buildNumber
