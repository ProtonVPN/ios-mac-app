#!/bin/bash -e
#
# This is an interactive script for nominating releases for promotion.
#
# Usage: nominate.sh <train> <version> <channel>
#
# <channel> should be either beta or production.

LHC_TRAIN=$1
VERSION=$2
LHC_RELEASE_CHANNEL=$3
LHC_REFS_ATTR=refs/notes/proton/attrs

AUTHOR="$(git config user.name) <$(git config user.email)>"

function fetch() {
    git fetch origin "+refs/notes/*:refs/notes/*" "+refs/tags/*:refs/tags/*"
}

function set_trailer() {
    case "$LHC_RELEASE_CHANNEL" in
      beta|production) TRAILER="Nominated-By" ;;
      * ) echo "Invalid option $LHC_RELEASE_CHANNEL. Please enter either beta or production."; exit 1;;
    esac

    mint run -s git-lhc attr add --train "$LHC_TRAIN" "${TRAILER}=${AUTHOR}" "${LHC_TRAIN}/${VERSION}"
}

function push() {
    git push origin $LHC_REFS_ATTR
}

if [ -z "$LHC_TRAIN" ] || [ -z "$VERSION" ] || [ -z "$LHC_RELEASE_CHANNEL" ]; then
    echo "Usage: $0 <train> <channel> <version>"
    echo ""
    echo "train: one of the supported trains for this repo."
    echo "version: the version to nominate for promotion."
    echo "channel: one of beta or production."
    exit 1
fi

fetch
set_trailer
push
