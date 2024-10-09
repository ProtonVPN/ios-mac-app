#!/bin/bash

# Files deleted here are not used in VPN app, but take quite a lot of space when bundled
# in the app and its extensions.
# The script can be deleted when Accounts team will stop including assets for
# other apps in UIFoundations library. (CP-8807)
#

# Enables `echo !!` command
set -o history -o histexpand

FOLDER="external/protoncore/libraries/UIFoundations/Resources-Shared/Assets.xcassets/CoreModulesImages/LoginUI"
FILES_LIST=(${FOLDER}/CalendarTopImage.imageset ${FOLDER}/DriveTopImage.imageset ${FOLDER}/MailTopImage.imageset ${FOLDER}/PassTopImage.imageset)

rm -rf ${FILES_LIST[*]}
echo !!

