#!/usr/bin/env bash
set -eo pipefail

# Settings
export I18N_APP_PROJECT_NAME="ProtonVPN iOS/MacOS";
export I18N_PROTON_LIST="protonvpn/iOS";
export I18N_CONVERT_FROM="xliff";
export I18N_COMMIT_BRANCH="translations-test";#"develop";

PATH_XLIFF_DIR='./_translations'; # Add this folder to .gitignore

##
# The script runs this function when we run update-crowdin
# If we need to extract the translations into a file.
#
function extractTranslations {    
    xcodebuild -exportLocalizations -localizationPath $PATH_XLIFF_DIR 
    # This file will be uploaded to crowdin
    export I18N_SOURCE_FILE="$PATH_XLIFF_DIR/en.xcloc/Localized Contents/en.xliff";
}
