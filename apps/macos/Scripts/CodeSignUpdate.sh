#!/bin/bash

#  CodeSignUpdate.sh
#  SwiftPrivilegedHelperApplication
#
#  Created by Erik Berglund.
#  Copyright © 2018 Erik Berglund. All rights reserved.

set -e

###
### CUSTOM VARIABLES
###

bundleIdentifierApplication="ch.protonvpn.mac"
bundleIdentifierHelper="ch.protonvpn.ProtonVPNNetworkHelper"

###
### STATIC VARIABLES
###

infoPlist="${INFOPLIST_FILE}"

if [[ $( /usr/libexec/PlistBuddy -c "Print NSPrincipalClass" "${infoPlist}" 2>/dev/null ) == "NSApplication" ]]; then
    target="application"
else
    target="helper"
fi

oidAppleDeveloperIDCA="1.2.840.113635.100.6.2.6"
oidAppleDeveloperIDApplication="1.2.840.113635.100.6.1.13"
oidAppleMacAppStoreApplication="1.2.840.113635.100.6.1.9"
oidAppleWWDRIntermediate="1.2.840.113635.100.6.2.1"

###
### FUNCTIONS
###

function appleGeneric {
    printf "%s" "anchor apple generic"
}

function appleDeveloperID {
    printf "%s" "certificate leaf[field.${oidAppleMacAppStoreApplication}] /* exists */ or certificate 1[field.${oidAppleDeveloperIDCA}] /* exists */ and certificate leaf[field.${oidAppleDeveloperIDApplication}] /* exists */"
}

function appleMacDeveloper {
    printf "%s" "certificate 1[field.${oidAppleWWDRIntermediate}]"
}

function identifierApplication {
    printf "%s" "identifier \"${bundleIdentifierApplication}\""
}

function identifierHelper {
    printf "%s" "identifier \"${bundleIdentifierHelper}\""
}


function developerID {
    developmentTeamIdentifier="${DEVELOPMENT_TEAM}"
    if ! [[ ${developmentTeamIdentifier} =~ ^[A-Z0-9]{10}$ ]]; then
        printf "%s\n" "Invalid Development Team Identifier: ${developmentTeamIdentifier}"
        exit 1
    fi

    printf "%s" "certificate leaf[subject.OU] = ${developmentTeamIdentifier}"
}

function macDeveloper {
    macDeveloperCN="${EXPANDED_CODE_SIGN_IDENTITY_NAME}"
    if ! [[ ${macDeveloperCN} =~ ^Mac\ Developer:\ .*\ \([A-Z0-9]{10}\)$ ]]; then
        printf "%s\n" "Invalid Mac Developer CN: ${macDeveloperCN}"
        exit 1
    fi

    printf "%s" "certificate leaf[subject.CN] = \"${macDeveloperCN}\""
}

function updateSMPrivilegedExecutables {
    /usr/libexec/PlistBuddy -c 'Delete SMPrivilegedExecutables' "${infoPlist}" || true
    /usr/libexec/PlistBuddy -c 'Add SMPrivilegedExecutables dict' "${infoPlist}"
    /usr/libexec/PlistBuddy -c 'Add SMPrivilegedExecutables:'"${bundleIdentifierHelper}"' string '"$( sed -E 's/\"/\\\"/g' <<< ${1})"'' "${infoPlist}"
}

function updateSMAuthorizedClients {
    /usr/libexec/PlistBuddy -c 'Delete SMAuthorizedClients' "${infoPlist}" || true
    /usr/libexec/PlistBuddy -c 'Add SMAuthorizedClients array' "${infoPlist}"
    /usr/libexec/PlistBuddy -c 'Add SMAuthorizedClients: string '"$( sed -E 's/\"/\\\"/g' <<< ${1})"'' "${infoPlist}"
}

###
### MAIN SCRIPT
###

case "${ACTION}" in
    "build")
        appString=$( identifierApplication )
        appString="${appString} and $( appleGeneric )"
        appString="${appString} and $( macDeveloper )"
        appString="${appString} and $( appleMacDeveloper )"
        appString="${appString} /* exists */"

        helperString=$( identifierHelper )
        helperString="${helperString} and $( appleGeneric )"
        helperString="${helperString} and $( macDeveloper )"
        helperString="${helperString} and $( appleMacDeveloper )"
        helperString="${helperString} /* exists */"
    ;;
    "install")
        appString=$( appleGeneric )
        appString="${appString} and $( identifierApplication )"
        appString="${appString} and ($( appleDeveloperID )"
        appString="${appString} and $( developerID ))"

        helperString=$( appleGeneric )
        helperString="${helperString} and $( identifierHelper )"
        helperString="${helperString} and ($( appleDeveloperID )"
        helperString="${helperString} and $( developerID ))"
    ;;
    *)
        printf "%s\n" "Unknown Xcode Action: ${ACTION}"
        exit 1
    ;;
esac

case "${target}" in
    "helper")
        updateSMAuthorizedClients "${appString}"
    ;;
    "application")
        updateSMPrivilegedExecutables "${helperString}"
    ;;
    *)
        printf "%s\n" "Unknown Target: ${target}"
        exit 1
    ;;
esac
