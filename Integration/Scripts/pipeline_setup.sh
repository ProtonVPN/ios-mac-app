#!/bin/bash
# Script invoked in Gitlab by the auto-generated output from in Integration/Templates/gitlab-pipeline.yml
#
# CREDENTIALS: path to credentials script
# MACROS_ALLOWLIST_PATH: path to Swift macros allow list
# MACROS_ALLOWLIST_INSTALL_DIR: path to install directory for Swift macros allow list on local machine

CREDENTIALS="./Integration/Scripts/credentials.sh"
MACROS_ALLOWLIST_PATH="./Integration/Gitlab/misc/macros.json"
MACROS_ALLOWLIST_INSTALL_DIR="~/Library/org.swift.swiftpm/security"

# Delete all ssh private keys
ssh-add -D 

# Add private key for access to gitlab
echo "$CI_SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add - > /dev/null

# Setup git identity
git config --local user.email $GIT_CI_EMAIL
git config --local user.name $GIT_CI_USERNAME

# Save gitlab servers public key
[ -n "$(ssh-keygen -F $CI_SERVER_HOST)" ] || ssh-keyscan -H $CI_SERVER_HOST >> ~/.ssh/known_hosts

# Change origin to use ssh as the backend
git remote rm origin && git remote add origin "git@${CI_SERVER_HOST}:${CI_PROJECT_PATH}.git"

# Don't fetch secrets unless we're cloning the whole repository, i.e., for a build
if [ "$GIT_STRATEGY" != "none" ] && [ "$GIT_SUBMODULE_STRATEGY" != "none" ]; then
    echo "Cloning secrets..."
    # Download obfuscated constants
    "$CREDENTIALS" cleanup
    GIT_LFS_SKIP_SMUDGE=1 "$CREDENTIALS" setup -s \
        -p .secrets-ci-${CI_JOB_ID} \
        -r "https://bot:${CI_SECRETS_REPO_KEY}@${CI_SERVER_HOST}/${CI_SECRETS_REPO_PATH}"
    "$CREDENTIALS" checkout -- .
fi

# Install allowlist of macros, or Xcode gets very fussy and cryptic with builds
cat "$MACROS_ALLOWLIST_PATH"
rm -f "${MACROS_ALLOWLIST_INSTALL_DIR}/$(basename $MACROS_ALLOWLIST_PATH)" || true
mkdir -p "$MACROS_ALLOWLIST_INSTALL_DIR" || true
cp "$MACROS_ALLOWLIST_PATH" "${MACROS_ALLOWLIST_INSTALL_DIR}/$(basename $MACROS_ALLOWLIST_PATH)"

# Check if 'mint bootstrap' is already running
while pgrep -f "mint bootstrap" > /dev/null; do
    echo "Another instance of 'mint bootstrap' is running. Waiting..."
    sleep 5
done

mint bootstrap -v --link --overwrite=y
