#!/bin/bash -e
# Setup keys and verify tags/nominations in CI.

SCRIPT_DIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
REPO_PATH=$(cd "${SCRIPT_DIR}/../.." && pwd) # script is in Integration/Scripts
KEYS_PATH="${REPO_PATH}/KEYS"

KEY_SERVER="hkps://mail-api.proton.me"
CI_ADDRESS="vpn-ci-service@proton.ch"

export LANG=en_US

echo "== Importing CI key..."
# Then we import the key and grab its long key ID (short ones are easy to fake).
TRUSTED_KEY_ID=$(
    echo "1" |
        gpg --no-tty --keyserver "$KEY_SERVER" --status-fd=1 --command-fd=0 --search "$CI_ADDRESS" |
        grep -o '^\[GNUPG:\] IMPORT_OK [0-9][0-9]* [0-9A-F][0-9A-F]*' |
        cut -d ' ' -f 4
)

# Then we go ahead and immediately trust the key, which has signed all of the keys in the KEYS file.
echo "== Setting trust for key id ${TRUSTED_KEY_ID}..."
echo -e "trust\n5\ny\n" | gpg --no-tty --status-fd=1 --command-fd=0 --edit-key "$TRUSTED_KEY_ID"

# After this we can import the commit signing keys. Commit and tag signatures and attributes should be fully trusted now.
echo "== Importing keys in ${KEYS_PATH}..."
gpg --no-tty --import "$KEYS_PATH"

# Setup keys and verify tags/nominations (releases only)
if grep "\d\d*\.\d\d*\.\d\d*-alpha\.\d\d*" <<< "$CI_COMMIT_TAG" > /dev/null; then
    echo "== Verifying signature on alpha tag..."

    SIG=$(git verify-tag --raw "$CI_COMMIT_TAG" 2> /dev/stdout | cut -d ' ' -f 2)
    if ! grep GOODSIG <<< "$SIG" > /dev/null; then
        echo "Error: invalid signature for tag."
        exit 1
    fi

    if ! grep VALIDSIG <<< "$SIG" > /dev/null; then
        echo "Error: signature for tag has expired."
        exit 1
    fi

    if ! grep TRUST_FULLY <<< "$SIG" > /dev/null; then
        echo "Error: signature for tag is not trusted."
        exit 1
    fi

    echo "Good signature on alpha tag."
  elif grep "\d\d*\.\d\d*\.\d\d*\(-beta\.\d\d*\)*" <<< "$CI_COMMIT_TAG" > /dev/null; then
    VERIFY_TRAIN=$(cut -d '/' -f 1 <<< "$CI_COMMIT_TAG")

    if grep "\d\d*\.\d\d*\.\d\d*-beta\.\d\d*" <<< "$CI_COMMIT_TAG" > /dev/null; then
        PREV_CHANNEL=alpha
    else
        PREV_CHANNEL=beta
    fi

    echo "== Verifying nomination on previous $PREV_CHANNEL tag..."

    NOMINATED=false
    PREV_VERSIONS=$(git tag --points-at "${CI_COMMIT_TAG}^{}" | grep "\d\d*\.\d\d*\.\d\d*-${PREV_CHANNEL}\.\d\d*")

    if [ -z "$PREV_VERSIONS" ]; then
        echo "Error: no previous ${PREV_CHANNEL} tag was pushed. Tags in a release train must proceed from alpha, to beta, then to production."
        exit 1
    fi

    IFS=$'\n'
    for version in $PREV_VERSIONS; do
        VERIFY_VERSION=$(cut -d '/' -f 2 <<< "$version")

        # Verify the nomination of the current version.
        if Integration/Scripts/nominate.sh verify -t "$VERIFY_TRAIN" -v "$VERIFY_VERSION"; then
            NOMINATED=true
        fi
    done

    if [ "$NOMINATED" == "false" ]; then
        echo "Error: previous tag for $CI_COMMIT_TAG has not been properly nominated. Please check with QA before proceeding."
        exit 2
    fi

    # Verify the nomination of the Core repository.
    CORE_PATH="external/protoncore"
    CORE_VERSION=$(git config -f .gitmodules --get submodule."$CORE_PATH".tag)

    if [ -z "$CORE_VERSION" ]; then
        echo "Error: no Proton Core tag is specified in .gitmodules, please correct this before releasing publicly."
    fi

    REPO="$PWD"
    cd "$CORE_PATH"

    git fetch origin "+refs/tags/${CORE_VERSION}:refs/tags/${CORE_VERSION}"

    CORE_REV=$(git rev-parse "${CORE_VERSION}^{}")

    # Make sure what's checked in at "$CORE_PATH" matches what's in `.gitmodules`.
    if [ "$CORE_REV" != "$(git rev-parse HEAD)" ]; then
        echo "Fatal: rev at $CORE_PATH does not match $CORE_VERSION in .gitmodules."
        exit 3
    fi

    cd "$REPO"
    echo "== Verifying nomination on Proton Core version $CORE_VERSION..."
    ./Integration/Scripts/nominate.sh verify -C "$CORE_PATH" -v "$CORE_VERSION" -a "VPN-Nominated-By"
fi
