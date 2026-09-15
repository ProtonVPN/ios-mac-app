#!/bin/bash
#
# Sorts the testTargets array of .xctestplan files by target name, so the
# insertion order Xcode writes never shows up as a diff.
#
# Usage:
#   format-xctestplans.sh            format every .xctestplan tracked by git
#   format-xctestplans.sh --staged   format only staged .xctestplan files and
#                                    re-stage them (use this in pre-commit)
#   format-xctestplans.sh FILE...    format the given files only (for hook
#                                    managers that pass the changed paths)
#
# Files are discovered through git, so ignored directories such as .build/
# and .build/checkouts/ are skipped without being listed here. Files are
# formatted in parallel, one jq process per file, up to the number of CPUs.
# Written for the bash 3.2 that ships with macOS.

# Hooks sometimes start this as `sh script`, which ignores the shebang and,
# where sh is dash, rejects the bash syntax below. Re-run under bash in that
# case. This block is the only code the other shell reads, so it is POSIX sh.
if [ -z "${BASH_VERSION-}" ]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    echo "format-xctestplans: jq is not installed, skipping (brew install jq)" >&2
    exit 0
fi

scope=all
case "${1-}" in
    "" | --all) scope=all ;;
    --staged)   scope=staged ;;
    -h | --help)
        sed -n '3,/^$/{s/^# \{0,1\}//;p;}' "$0"
        exit 0
        ;;
    -*)
        echo "format-xctestplans: unknown option $1" >&2
        exit 2
        ;;
    *) scope=args ;;
esac

# Paths from git are relative to the repository root; explicit FILE arguments
# are resolved from the caller's directory, so only change directory when
# git provides the list.
if [ "$scope" != args ]; then
    repo_root=$(git rev-parse --show-toplevel)
    cd "$repo_root"
fi

# Path lists stay NUL-separated end to end: git emits them with -z and reads
# them back with --pathspec-file-nul, so spaces, newlines, non-ASCII names
# (which core.quotePath would otherwise escape) and glob characters all pass
# through untouched. --literal-pathspecs stops git from treating *, ? and
# [ in a file name as patterns. They live in temp files because bash
# variables cannot hold NUL bytes.
list=$(mktemp "${TMPDIR:-/tmp}/format-xctestplans.XXXXXX")
changed=$(mktemp "${TMPDIR:-/tmp}/format-xctestplans.XXXXXX")
trap 'rm -f "$list" "$changed"' EXIT

case $scope in
    all)    git ls-files -z -- '*.xctestplan' > "$list" ;;
    staged) git diff --cached --name-only -z --diff-filter=ACMR -- '*.xctestplan' > "$list" ;;
    args)   printf '%s\0' "$@" > "$list" ;;
esac

# Nothing to do. Exiting here also keeps the xargs calls below from running
# git with an empty pathspec, which would mean "every file".
if [ ! -s "$list" ]; then
    exit 0
fi

# With --staged the formatted files get re-added afterwards. Refuse when any
# of them already differs between working tree and index, otherwise the
# re-add would silently stage those unrelated edits too.
if [ "$scope" = staged ]; then
    xargs -0 git --literal-pathspecs diff --name-only -z -- < "$list" > "$changed"
    if [ -s "$changed" ]; then
        echo "format-xctestplans: unstaged changes in staged test plans, stage or stash them first:" >&2
        tr '\0' '\n' < "$changed" | sed 's/^/  /' >&2
        exit 1
    fi
fi

# Runs in a child bash started by xargs, one call per file. Rewrites the file
# only when sorting changes it. Returns 1 on any problem; xargs keeps going
# and reports failure at the end, so every bad file is listed in one run.
format_file() {
    local file=$1 tmp=$1.tmp

    if [ ! -f "$file" ]; then
        # The git index can list a plan that was deleted in the working tree
        # but not yet staged; that is not this script's business. An explicit
        # argument that does not exist is a caller error.
        if [ "$scope" = args ]; then
            echo "format-xctestplans: no such file: $file" >&2
            return 1
        fi
        return 0
    fi

    if ! jq "$FILTER" "$file" > "$tmp"; then
        rm -f "$tmp"
        echo "format-xctestplans: invalid JSON in $file" >&2
        return 1
    fi

    if cmp -s "$tmp" "$file"; then
        rm -f "$tmp"
        return 0
    fi

    mv -f "$tmp" "$file"
    echo "formatted $file"
}

export FILTER='if has("testTargets") then .testTargets |= sort_by(.target.name) else . end'
export scope
export -f format_file

workers=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)

status=0
xargs -0 -P "$workers" -n 1 bash -c 'format_file "$1"' _ < "$list" || status=1

# git add is done once from here rather than inside format_file: concurrent
# workers would race for .git/index.lock. The dirty check above guarantees
# that every file now differing from the index is one this script rewrote.
if [ "$scope" = staged ]; then
    xargs -0 git --literal-pathspecs diff --name-only -z -- < "$list" > "$changed"
    if [ -s "$changed" ]; then
        git --literal-pathspecs add --pathspec-from-file="$changed" --pathspec-file-nul
    fi
fi

exit "$status"
