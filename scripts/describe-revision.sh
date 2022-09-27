#!/bin/bash -e
# describe-revision: Use git describe to find the last matching tag for either
# ios or mac releases. If the repo is dirty, provide further disambiguation by
# getting the first ten characters of the shasum of the git status and diff.
#
# If the version is a beta or public release, this string will look something
# like ios/4.0.2 or mac/beta/3.0.3-2209190438.
# If the code is based on a tag and hasn't yet been released, the string will
# look something like ios/4.0.2-58-gfde0845b9, where `58` is the number of
# commits since the most recent tag, and `gfde0845b9` is the current commit
# hash.
# If there is uncommitted code in the current branch, the string will look
# something like ios/4.0.2-58-gfde0845b9-dirty-d1aef45ce8.
#
# This is to help developers disambiguate which code is actually installed and
# running on their machine, since the app will log this when the user goes to
# show their application logs. If QA has a debug or locally-built branch, for
# example, reading this line in the log messages will help determine if the
# desired version is actually installed.

# add homebrew to path in case lfs is there
PATH="${PATH}:/opt/homebrew/bin"

REVISION_INFO_KEY="RevisionInfo"
MATCH="$1"
INFOPLIST_PATH="$2"

# This script expects to be in the 'scripts' dir of the ProtonVPN Apple repo.
SRCROOT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/..


function usage() {
	echo "Usage: $0 [mac|ios] <path to info plist>"
	exit 1
}

if [[ !("$MATCH" == "mac" || "$MATCH" == "ios") ]]; then
	echo "Error: Should match either mac or ios tags; asked to match $MATCH"
	usage
fi

if [[ ! -f "$INFOPLIST_PATH" ]]; then
	echo "Error: Info plist file should exist at \"$INFOPLIST_PATH\"; no such file found."
	usage
fi

echo "Describing revision using $MATCH tags."

DIRTY="-dirty-`(git -C \"$SRCROOT\" status && git -C \"$SRCROOT\" diff) | shasum | head -c 10`"
echo "Marker if dirty: $DIRTY"

REVINFO=`git -C "$SRCROOT" describe --tags --match "${MATCH}*" --dirty="$DIRTY"`
echo "Setting $REVISION_INFO_KEY => \"$REVINFO\" in \"$INFOPLIST_PATH\"."

plutil -insert $REVISION_INFO_KEY \
	-string "$REVINFO" \
	"$INFOPLIST_PATH"

echo "Done."
