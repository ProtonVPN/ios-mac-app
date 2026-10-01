#!/bin/bash
# Script invoked in Gitlab by the auto-generated output from in Integration/Templates/gitlab-pipeline.yml
#
# CREDENTIALS: path to credentials script
# MACROS_ALLOWLIST_PATH: path to Swift macros allow list
# MACROS_ALLOWLIST_INSTALL_DIR: path to install directory for Swift macros allow list on local machine

CREDENTIALS="./Integration/Scripts/credentials.sh"

mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Setup git identity
git config --global user.email $GIT_CI_EMAIL
git config --global user.name $GIT_CI_USERNAME

# Add aliases for using the job token when contacting GitLab
git config --global --add "url.https://gitlab-ci-token:${CI_JOB_TOKEN}@${CI_SERVER_HOST}.insteadOf" "https://${CI_SERVER_HOST}"
git config --global --add "url.https://gitlab-ci-token:${CI_JOB_TOKEN}@${CI_SERVER_HOST}.insteadOf" "ssh://git@${CI_SERVER_HOST}"
git config --global --add "url.https://gitlab-ci-token:${CI_JOB_TOKEN}@${CI_SERVER_HOST}/.insteadOf" "git@${CI_SERVER_HOST}:"

# Don't fetch secrets unless we're cloning the whole repository, i.e., for a build, or if we're trying to upload
# localizations
if ([ "$GIT_STRATEGY" != "none" ] && [ "$GIT_SUBMODULE_STRATEGY" != "none" ]) || [ -n "$I18N_SYNC_CROWDIN_PROJECT" ]; then
    echo "Cloning secrets..."
    # Download obfuscated constants
    "$CREDENTIALS" cleanup
    GIT_LFS_SKIP_SMUDGE=1 "$CREDENTIALS" setup -s \
        -p .secrets-ci-${CI_JOB_ID} \
        -r "https://${CI_SERVER_HOST}/${CI_SECRETS_REPO_PATH}"
    "$CREDENTIALS" checkout -- .
fi

if [ "$SKIP_MACROS_SETUP" != "true" ]; then
    defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
fi

defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write com.apple.dt.Xcode IDEPackageEnablePrebuilts YES

if [ "$SKIP_MINT_BOOTSTRAP" != "true" ]; then
    # Check if 'mint bootstrap' is already running
    while pgrep -f "mint bootstrap" > /dev/null; do
        echo "Another instance of 'mint bootstrap' is running. Waiting..."
        sleep 5
    done

    mint bootstrap --verbose --link --overwrite=y
fi
