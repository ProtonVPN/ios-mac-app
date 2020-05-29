#!/bin/bash

cd ..
buildNumber=$(date +"%m%d%H%M")
xcrun agvtool new-version -all $buildNumber
