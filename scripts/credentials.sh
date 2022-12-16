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

SCRIPT_NAME="$0"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [[ "$1" == "setup" ]]; then
	if [[ "$2" == "" || "$3" == "" ]]; then
		echo "Usage: $0 setup <path to credentials dir> <credentials remote>"
		echo
		echo "Environment variables:"
		echo -e "\tDEFAULT_CREDS_BRANCH: the branch to use when first setting up. Defaults to main."
		exit 1
	fi

	GIT_REMOTE="$3"

	mkdir -p "$2"
	FULL_PATH=$(cd "$2" && pwd)

	git config --global vpn.credsdir "$FULL_PATH"
	git clone --bare "$GIT_REMOTE" "$FULL_PATH"

	cd "$FULL_PATH"
	# we need to set up fetches to work correctly. for some reason they don't track all branches
	# when cloning a bare repository.
	git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

	# don't show all of the files in the repository when using 'git status', only ones that are
	# already tracked in the credentials repo.
	git config status.showUntrackedFiles no

	# now, fetch all of the remote branches after we've configured it properly.
	git fetch

	# once we've fetched, populate the project directory with the files from the desired branch.
	git --git-dir="$FULL_PATH" --work-tree="$SCRIPT_DIR/.." checkout -f "${DEFAULT_CREDS_BRANCH:-main}"

	echo "Credentials repository setup successfully."
	exit 0
elif [[ "$1" == "xcodepull" ]]; then
	shift # remove xcodepull from arguments

	VPN_SERVER_NAME=$(git config --get vpn.internal || true)
	CONNECTED_NAME=$(defaults read ch.protonvpn.mac ConnectedServerNameDoNotUse 2> /dev/null || true)

	if [[ ! -z "$VPN_SERVER_NAME" ]] && [[ "$VPN_SERVER_NAME" != "$CONNECTED_NAME" ]]; then
		exit 0
	fi

	exec "$0" pull "$@"
fi

CREDENTIALS_DIR=$(git config --get vpn.credsdir)

exec git --git-dir="$CREDENTIALS_DIR" --work-tree="$SCRIPT_DIR/.." "$@"
