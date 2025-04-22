#!/bin/bash -e
#
# This is an interactive script for creating tags with git-lhc according to the release notes defined in the commit
# attributes. It prompts the user for the release notes and then creates a new release according to the options.
#
# Usage: release.sh -t <train> -c <channel> [-f <forced-version>] [-l | -n | -v <version> | <reference>]
#

SCRIPT_DIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
REPO_PATH=$(cd "${SCRIPT_DIR}/../.." && pwd) # script is in Integration/Scripts
MYSELF=$0

EDITOR=${EDITOR:-$(which nano)}
RELEASE_NOTES_TEMPLATE=release-notes.md
OUTPUT_DIRECTORY=output
MAX_TAG_DEPTH=50
NOMINATION_ATTR="Nominated-By"
MINT_SILENT="-s"

function usage() {
    echo "Usage: $MYSELF -t <train> -c <channel> [-S -f <forced-version>] [-l | -n | -v <version> | <reference>]"
    echo ""
    echo "-t <train>: one of the supported trains for this repo."
    echo "-c <channel>: specify if the new release(s) is/are for alpha, beta, production, or all. See below."
    echo "-f <forced-version> (optional): override the version number to set for the release."
    echo "-S (optional): don't sync tags or notes before or after the operation(s)."
    echo ""
    echo "One and only one of the following must be specified:"
    echo "-l: create a new tag for the latest commit on develop."
    echo "-n: create a new tag for the latest nominated release."
    echo "-v <version>: create a new tag which promotes the given version."
    echo "<reference>: create a new tag from the given reference."
    echo ""
    echo "Special values:"
    echo "-c @all: creates an alpha build from develop, and checks for nominations for beta and production."
}

if [ "$SKIP_CLEAN_CHECK" != "true" ] && [ -n "$(git status --porcelain)" ]; then
    echo "Error: your repository is not clean. Make sure you've stashed or committed any unstaged changes and try again."
    exit 2
fi

function error_cannot_also_reference() {
    echo "Error: already promoting $REFERENCE - cannot also promote $1."
    usage
    exit 3
}

function error_cannot_nominate_channel() {
    echo "Error: cannot promote builds nominated for $1 release."
    usage
    exit 4
}

function error_unrecognized_channel() {
    echo "Error: unrecognized channel $1."
    usage
    exit 5
}

function error_cant_specify_this_with_all() {
    echo "Error: can't specify $1 with '-c @all'."
    usage
    exit 6
}

function fetch() {
    [ -z "$SKIP_SYNC" ] || return 0

    echo "Fetching from remote..."
    git fetch origin "+refs/notes/*:refs/notes/*" "+refs/tags/${LHC_TRAIN}/*:refs/tags/${LHC_TRAIN}/*" 2> /dev/null
}

function make_release_notes() {
    echo "Checking out $REFERENCE..."
    git checkout "$REFERENCE" 2> /dev/null

    mint run -m "${REPO_PATH}/Mintfile" $MINT_SILENT git-lhc describe \
        --channel "$LHC_RELEASE_CHANNEL" \
        --train "$LHC_TRAIN" \
        --show head \
        --template "$RELEASE_NOTES_TEMPLATE" \
        --output "${OUTPUT_DIRECTORY}/"

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
    [ -n "$SKIP_SYNC" ] || PUSH="--push"

    mint run -m "${REPO_PATH}/Mintfile" $MINT_SILENT git-lhc new \
        --channel "$LHC_RELEASE_CHANNEL" \
        --train "$LHC_TRAIN" \
        --release-notes "${OUTPUT_DIRECTORY}/${RELEASE_NOTES_TEMPLATE}" $PUSH $FORCED_VERSION
}

function cleanup() {
    rm -rf "$OUTPUT_DIRECTORY"
    git checkout -
}

# Resolve the reference to promote according to the other options specified. This has to be run after
# argument parsing to make sure all options are present and validated.
# In some cases, we're happy with exiting the program early and with a non-zero exit code, because we
# haven't found anything that needs to be done.
function resolve_reference() {
    case "$REFERENCE" in
        branch*|reference*) # Use the second value verbatim.
            REFERENCE="$(cut -d " " -f 2 <<< "$REFERENCE")"
            ;;
        version*) # Use the train as a tag prefix.
            REFERENCE="${LHC_TRAIN}/$(cut -d " " -f 2 <<< "$REFERENCE")"
            ;;
        latest*) # Search for the last tag that had a QA nomination attribute.
            case "$LHC_RELEASE_CHANNEL" in
                beta)
                    CANDIDATE_FILTER="alpha"
                    ;;
                production)
                    CANDIDATE_FILTER="beta"
                    ;;
                *) error_cannot_nominate_channel "$LHC_RELEASE_CHANNEL"
                    ;;
            esac

            unset REFERENCE
            IFS=$'\n'
            for tag in $(git tag | grep "^${LHC_TRAIN}\/\d\d*\.\d\d*\.\d\d*\-${CANDIDATE_FILTER}" | sort -rV | head -n $MAX_TAG_DEPTH); do
                local attr_value
                if ! attr_value=$(mint run -m "${REPO_PATH}/Mintfile" $MINT_SILENT git-lhc attr get --train "$LHC_TRAIN" "$NOMINATION_ATTR" "$tag") ; then
                    continue
                fi

                SHORT_VERSION=$(cut -d "-" -f 1 <<< "$tag")
                if [ "$LHC_RELEASE_CHANNEL" == "beta" ]; then
                    EXISTING_FILTER="tag: ${SHORT_VERSION}-beta"
                else
                    EXISTING_FILTER="tag: ${SHORT_VERSION}\\(,\\|)\\)"
                fi

                if git log "$tag" --format="%d" -n 1 | grep "$EXISTING_FILTER" > /dev/null ; then
                    # We already promoted for this channel, no need to proceed.
                    break
                fi

                if ! "${SCRIPT_DIR}/nominate.sh" verify -T undefined -S -t "$LHC_TRAIN" -a "$NOMINATION_ATTR" "$tag" > /dev/null; then
                     echo "Warning: invalid or missing signature for nomination: $attr_value, please confirm with nominator."
                     echo "Deploy will likely fail if you choose to proceed!"
                fi

                REFERENCE="$tag"
                break
            done

            if [ -z "$REFERENCE" ]; then
                echo "No nominated and unpromoted references found."
                exit 0
            fi
            ;;
        *) break;;
    esac
}

while getopts ":ht:c:f:v:nldS" arg; do
  case $arg in
    d) # Debug mode
      set -x
      MINT_SILENT=""
      ;;
    t) # Specify train.
      export LHC_TRAIN=${OPTARG}
      ;;
    c) # Specify release channel.
      case "$OPTARG" in
          alpha|beta|production|@all) export LHC_RELEASE_CHANNEL=${OPTARG} ;;
          *) error_unrecognized_channel "$OPTARG" ;;
      esac
      ;;
    f) # Specify the new version name.
      FORCED_VERSION=${OPTARG}
      ;;
    l) # We want to promote the latest commit on develop.
      WANT="branch origin/develop"
      [ -z "$REFERENCE" ] || error_cannot_also_reference "$WANT"
      REFERENCE=$WANT
      ;;
    n) # We want to promote the latest nominated release in the last channel.
      WANT="latest nominated build"
      [ -z "$REFERENCE" ] || error_cannot_also_reference "$WANT"
      REFERENCE=$WANT
      ;;
    v) # We want to promote a specific version.
      WANT="version $OPTARG"
      [ -z "$REFERENCE" ] || error_cannot_also_reference "$WANT"
      REFERENCE=$WANT
      ;;
     S)
      SKIP_SYNC="-S"
      ;;
    h | *) # Display help.
      usage
      exit 0
      ;;
    --) # Exit the loop.
      break
      ;;
  esac
done
shift $(($OPTIND - 1))

for var in "$@"; do
    WANT="reference $var"
    [ -z "$REFERENCE" ] || error_cannot_also_reference "$WANT"
    REFERENCE=$WANT
done

# Special case: spawn three instances of ourselves again to handle promoting all channels.
if [ "$LHC_RELEASE_CHANNEL" == "@all" ]; then
    if [ -n "$REFERENCE" ]; then
        error_cant_specify_this_with_all "$REFERENCE"
    fi

    if [ -n "$FORCED_VERSION" ]; then
        error_cant_specify_this_with_all "forced version $FORCED_VERSION"
    fi

    "$0" $SKIP_SYNC -t "$LHC_TRAIN" -c alpha -l
    "$0" $SKIP_SYNC -t "$LHC_TRAIN" -c beta -n
    "$0" $SKIP_SYNC -t "$LHC_TRAIN" -c production -n
    exit 0
fi

if [ -z "$LHC_TRAIN" ] || [ -z "$LHC_RELEASE_CHANNEL" ] || [ -z "$REFERENCE" ]; then
    usage
    exit 1
fi

fetch
resolve_reference
make_release_notes
make_release
cleanup
