#!/bin/bash -e
#
# Used for testing credentials. Invoke as you would a `git` command. For example:
# scripts/credentials.sh push origin main
#
# To setup:
# ./scripts/credentials.sh setup <path to credentials repo> <credentials remote>
#
# Then:
# ./scripts/credentials.sh checkout

if [[ "$1" == "setup" ]]; then
	if [[ "$2" == "" || "$3" == "" ]]; then
		echo "Usage: $0 setup <path to credentials dir> <credentials remote>"
		exit 1
	fi

	GIT_REMOTE="$3"

	mkdir -p "$2"
	FULL_PATH=$(cd "$2" && pwd)

	git config --global vpn.credsdir "$FULL_PATH"
	git clone --bare "$GIT_REMOTE" "$FULL_PATH"

	echo "Credentials repository setup successfully."
	exit 0
fi

CREDENTIALS_DIR=$(git config --get vpn.credsdir)
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

git --git-dir="$CREDENTIALS_DIR" --work-tree="$SCRIPT_DIR/.." "$@"
