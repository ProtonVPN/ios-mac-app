#!/bin/bash -e
#
# Used for testing credentials. Invoke as you would a `git` command. For example:
# scripts/credentials.sh push origin main
#
# To setup:
# ./scripts/credentials.sh setup -p <path to credentials repo> -r <credentials remote>
#
# Then:
# ./scripts/credentials.sh checkout

SCRIPT_NAME="$0"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CONFIG_NAME="vpn.credsdir"

## Built-in commands

function setup() {
	local dont_write_config="$1"
	local shallow_clone="$2"
	local repo_path="$3"
	local git_remote="$4"

	if [ -d "$repo_path" ]; then
		echo "Credentials repo already exists at \"$repo_path\"; please delete it first with 'cleanup'." > /dev/stderr
		exit 0 # To keep CI scripts from exiting early due to an error
	elif [ "$repo_path" == "$(directory)"  ]; then
		echo "== Cleaning up stale repo config..."
		# If the directory doesn't exist, but git config still points to it, do a cleanup
		# and continue with normal setup.
		cleanup
	fi

	mkdir -p "$repo_path"
	local full_path=$(cd "$repo_path" && pwd)

	[ "$dont_write_config" != "YES" ] && set_config "$full_path"

	echo "== Cloning (shallow = $shallow_clone) at $full_path."
	local clone_opts=""
	[ "$shallow_clone" == "YES" ] && clone_opts="--depth=1"
	git clone --bare $clone_opts "$git_remote" "$full_path"

	echo "== Setting config options..."
	cd "$full_path"
	# we need to set up fetches to work correctly. for some reason they don't track all branches
	# when cloning a bare repository.
	git config --file config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

	# don't show all of the files in the repository when using 'git status', only ones that are
	# already tracked in the credentials repo.
	git config --file config status.showUntrackedFiles no

	echo "== Fetching..."
	# now, fetch all of the remote branches after we've configured it properly.
	git fetch

	echo "== Checking out repository..."
	# once we've fetched, populate the project directory with the files from the desired branch.
	git --git-dir="$full_path" --work-tree="$SCRIPT_DIR/.." checkout -f "${DEFAULT_CREDS_BRANCH:-main}"

	echo "Credentials repository setup successfully."
	exit 0
}

function cleanup() {
	echo "Cleaning up credentials repository."
	local dir=$(directory)

	if [ ! -z "$dir" ] && [ -d "$dir" ]; then
		if [[ "$dir" == "$PWD"* ]]; then
			echo "Error: not removing repo directory $dir since PWD is $PWD." > /dev/stderr
			exit 1
		fi
		rm -rf "$dir" &> /dev/null || true
	fi

	unset_config
}

function directory() {
	git config --get "$CONFIG_NAME"
}

function xcodepull() {
	shift # remove xcodepull from arguments

	VPN_SERVER_NAME=$(git config --get vpn.internal || true)
	CONNECTED_NAME=$(defaults read ch.protonvpn.mac ConnectedServerNameDoNotUse 2> /dev/null || true)

	if [[ ! -z "$VPN_SERVER_NAME" ]] && [[ "$VPN_SERVER_NAME" != "$CONNECTED_NAME" ]]; then
		exit 0
	fi

	exec "$0" pull "$@"
}

## Helper functions

function invoke_setup() {
	shift

	local optstring=":hdsr:p:"
	while getopts "$optstring" arg; do
	  case "$arg" in
	    d) local dont_write_config="YES" ;;
	    s) local shallow_clone="YES" ;;
	    r) local repo_remote="$OPTARG" ;;
	    p) local repo_path="$OPTARG" ;;
	    h) setup_usage 0 ;;
	    ?) setup_usage 1 "Error: unknown option $OPTARG" ;;
	  esac
	done

	[ -z "$repo_path" ] || [ -z "$repo_remote" ] && setup_usage 1 "Error: please specify both repo path and remote."

	setup ${dont_write_config:-NO} ${shallow_clone:-NO} "$repo_path" "$repo_remote"
}

function setup_usage() {
	local exit_code="$1"
	local error_message="$2"

	if [ ! -z "$error_message" ]; then
		echo -e "$error_message"
		echo ""
	fi

	echo "$SCRIPT_NAME setup: install version controlled credentials"
	echo -e "\t-h: Show this help"
	echo -e "\t-d: Don't write $CONFIG_NAME to repository git config"
	echo -e "\t-s: Shallow clone (useful for CI)"
	echo -e "\t-r <remote url>: Specify repository remote (required)"
	echo -e "\t-p <path>: Specify repository path (required)"
	echo "Environment variables:"
	echo -e "\tDEFAULT_CREDS_BRANCH: the branch to use. Defaults to main."
	echo "Example:"
	echo -e "\t$SCRIPT_NAME setup -s -r https://github.com/repo/path -p ~/.credentials"

	exit $exit_code
}

function set_config() {
	local full_path="$1"
	local source_dir="${SCRIPT_DIR}/.."

	# set vpn.credsdir in the protonvpn repo config
	touch "$source_dir/.gitconfig"
	git config --file "$source_dir/.gitconfig" vpn.credsdir "$full_path"
}

function unset_config() {
	git config --unset "$CONFIG_NAME" || true
}

case "$1" in
	setup) invoke_setup $@; exit;;
	cleanup) cleanup; exit;;
	directory) directory; exit;;
	xcodepull) xcodepull $@; exit;;
	*);;
esac

exec git --git-dir="$(directory)" --work-tree="$SCRIPT_DIR/.." "$@"
