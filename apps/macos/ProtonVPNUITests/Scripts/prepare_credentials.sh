#!/bin/bash

echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>' > credentials.plist

## At least one user credentials have to be present
echo "<dict>
            <key>plan</key>
            <string>$IOS_VPNTEST_PLAN1</string>
            <key>username</key>
            <string>$IOS_VPNTEST_USER1</string>
            <key>password</key>
            <string>$IOS_VPNTEST_PASSWORD1</string>
        </dict>" >> credentials.plist

[ -n "$IOS_VPNTEST_USER2" ] && echo "<dict>
            <key>plan</key>
            <string>$IOS_VPNTEST_PLAN2</string>
            <key>username</key>
            <string>$IOS_VPNTEST_USER2</string>
            <key>password</key>
            <string>$IOS_VPNTEST_PASSWORD2</string>
        </dict>" >> credentials.plist


[ -n "$IOS_VPNTEST_USER3" ] && echo "<dict>
            <key>plan</key>
            <string>$IOS_VPNTEST_PLAN3</string>
            <key>username</key>
            <string>$IOS_VPNTEST_USER3</string>
            <key>password</key>
            <string>$IOS_VPNTEST_PASSWORD3</string>
        </dict>" >> credentials.plist

[ -n "$IOS_VPNTEST_USER4" ] && echo "<dict>
            <key>plan</key>
            <string>$IOS_VPNTEST_PLAN4</string>
            <key>username</key>
            <string>$IOS_VPNTEST_USER4</string>
            <key>password</key>
            <string>$IOS_VPNTEST_PASSWORD4</string>
        </dict>" >> credentials.plist

[ -n "$IOS_VPNTEST_USER5" ] && echo "<dict>
            <key>plan</key>
            <string>$IOS_VPNTEST_PLAN5</string>
            <key>username</key>
            <string>$IOS_VPNTEST_USER5</string>
            <key>password</key>
            <string>$IOS_VPNTEST_PASSWORD5</string>
        </dict>" >> credentials.plist

echo '</array>
</plist>' >> credentials.plist
