#!/bin/bash

cd ..
buildNumber=$(git rev-list HEAD | wc -l | tr -d ' ')
xcrun agvtool new-version -all $buildNumber
