#!/usr/bin/env bash
set -eo pipefail

if [ -f "$(pwd)/i18n.config.sh" ]; then
    source "$(pwd)/i18n.config.sh";
fi;

# Short version, enough to create a unique commit
LAST_COMMIT_SHORT="$CI_COMMIT_SHORT_SHA";
# Convert the URL to git else, the push doesn't work
APP_GIT_CI=`echo "$CI_REPOSITORY_URL" | perl -pe 's#.*@(.+?(\:\d+)?)/#git@\1:#'`;
# After changes are commited MR to this branch will be created
MAIN_BRANCH=${CI_COMMIT_BRANCH:="develop"}


# Prepare empty folder
[ -d "$PATH_XLIFF_DIR" ] && rm -rf "$PATH_XLIFF_DIR"
mkdir "$PATH_XLIFF_DIR"

# Get translations
git clone --branch $I18N_DEPENDENCY_BRANCH $I18N_DEPENDENCY_REPO $PATH_XLIFF_DIR

# Import translations into project
for file in $(ls "$PATH_XLIFF_DIR"); do
    output="$PATH_XLIFF_DIR/$file";
    echo "xcodebuild -importLocalizations -localizationPath $output"
    xcodebuild -importLocalizations -localizationPath $output 
done;

rm -rf "$PATH_XLIFF_DIR"


# Save changes to git and create MR

git remote set-url origin "$APP_GIT_CI"

date=$(date '+%Y-%m-%d_%H%M%S')
git checkout -b "translations/$date"

# Add updated files to git
git add *.pbxproj
git add *.strings
git add *.stringsdict

git status

# These options will create a Merge Request into the branch from which code was taken before import
MR_OPTIONS="-o merge_request.create -o merge_request.target=$MAIN_BRANCH -o merge_request.remove_source_branch"

(git commit -m "[i18n@$LAST_COMMIT_SHORT] ~ Upgrade translations from crowdin" && git push origin "$(git rev-parse --abbrev-ref HEAD)" $MR_OPTIONS) || echo "[i18n] Nothing to upgrade"


