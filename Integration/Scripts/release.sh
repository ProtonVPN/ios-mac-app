#!/bin/bash -e
#
# This is an interactive script for creating tags with git-lhc according to the release notes defined in the commit
# attributes. It prompts the user for the release notes and then creates a new release according to the options.
#
# Usage: release.sh <train> <channel> <reference> [forced-version]

TRAIN=$1
CHANNEL=$2
REFERENCE=$3
FORCED_VERSION=$4

EDITOR=${EDITOR:-$(which nano)}
RELEASE_NOTES_TEMPLATE=release-notes.md
OUTPUT_DIRECTORY=output

function fetch() {
    git fetch origin '+refs/notes/*:refs/notes/*' '+refs/tags/*:refs/tags/*'
}

function make_release_notes() {
    git checkout "$REFERENCE"
    mint run -s git-lhc describe --channel "$CHANNEL" --train "$TRAIN" --show head --template "$RELEASE_NOTES_TEMPLATE" --output "${OUTPUT_DIRECTORY}/"

    while true; do
        echo "Release notes:"
        cat "${OUTPUT_DIRECTORY}/${RELEASE_NOTES_TEMPLATE}"

        read -p "Edit (y/n)? " choice
        case "$choice" in
          y|Y|yes|Yes ) $EDITOR "${OUTPUT_DIRECTORY}/${RELEASE_NOTES_TEMPLATE}";;
          n|N|no|No ) break;;
          * ) echo "Invalid option $choice. Please enter either y or n.";;
        esac
    done
}

function make_release() {
    mint run -s git-lhc new --channel "$CHANNEL" --train "$TRAIN" --release-notes "${OUTPUT_DIRECTORY}/${RELEASE_NOTES_TEMPLATE}" --push $FORCED_VERSION
}

function cleanup() {
    rm -rf "$OUTPUT_DIRECTORY"
    git checkout -
}

if [ -n "$(git status --porcelain)" ]; then
    echo "Error: your repository is not clean. Make sure you've stashed or committed any unstaged changes and try again."
    exit 1
fi

if [ -z "$TRAIN" ] || [ -z "$CHANNEL" ] || [ -z "$REFERENCE" ]; then
    echo "Usage: $0 <train> <channel> <reference> [forced-version]"
    echo ""
    echo "train: one of the supported trains for this repo."
    echo "channel: one of alpha, beta, or production."
    echo "reference: any reference or git commit hash."
    echo "forced-version (optional): an overriding version to set for the release."
fi

fetch
make_release_notes
make_release
cleanup
