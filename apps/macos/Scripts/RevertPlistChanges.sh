#!/bin/bash

set -e

infoPlist="${INFOPLIST_FILE}"

if [[ $( /usr/libexec/PlistBuddy -c "Print NSPrincipalClass" "${infoPlist}" 2>/dev/null ) == "NSApplication" ]]; then
    target="application"
else
    target="helper"
fi

function updateAppPlist {
    /usr/libexec/PlistBuddy -c 'Delete SMPrivilegedExecutables' "${infoPlist}"
}

function updateHelperPlist {
    /usr/libexec/PlistBuddy -c 'Delete SMAuthorizedClients' "${infoPlist}"
}

case "${target}" in
    "helper")
        updateHelperPlist "${appString}"
    ;;
    "application")
        updateAppPlist "${helperString}"
    ;;
    *)
        printf "%s\n" "Unknown Target: ${target}"
        exit 1
    ;;
esac
