#!/bin/bash

cd ..
versionNumber=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "ProtonVPN/Info.plist")
xcrun agvtool new-marketing-version $versionNumber
