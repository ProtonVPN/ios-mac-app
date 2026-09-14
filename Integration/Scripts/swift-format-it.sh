#!/bin/bash
#
# Runs SwiftFormat over Swift files in the repository.
#
# Usage:
#   swift-format-it.sh             format the staged Swift files and re-stage
#   swift-format-it.sh --staged    them, so the commit contains the formatted
#                                  code (default; use this in pre-commit)
#   swift-format-it.sh --all       format every Swift file in the repository,
#                                  tracked or untracked but not ignored, and
#                                  leave the index alone
#
# Exits non-zero, which aborts the commit, when SwiftFormat fails or when, in
# staged scope, a staged Swift file also has unstaged changes: formatting the
# working tree and re-adding it would pull those unrelated edits into the
# commit. In --all scope unstaged changes are expected and nothing is staged.

# Hooks sometimes start this as `sh script`, which ignores the shebang. Re-run
# under bash in that case. This block is the only code the other shell reads.
if [ -z "${BASH_VERSION-}" ]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

# Git GUI apps start hooks without the login shell's PATH, so Homebrew's
# directories are missing and mint would not be found.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

script_name=$(basename "$0")

if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
    red=$(tput setaf 1) green=$(tput setaf 2) yellow=$(tput setaf 3)
    magenta=$(tput setaf 5) bold=$(tput bold) reset=$(tput sgr0)
else
    red="" green="" yellow="" magenta="" bold="" reset=""
fi

info()    { printf 'ℹ️ %s %s: %s%s\n' "$yellow" "$script_name" "$1" "$reset"; }
success() { printf '🟢%s%s %s: %s%s\n' "$green" "$bold" "$script_name" "$1" "$reset"; }
# Prints the message and exits 1. Nothing else in this script calls exit with
# a status of its own, and the EXIT trap only removes temp files, so this
# status is the one git sees.
fail()    { printf '🔴%s%s %s: ERROR: %s%s\n' "$red" "$bold" "$script_name" "$1" "$reset" >&2; exit 1; }

scope=staged
case "${1-}" in
    "" | --staged) scope=staged; scope_label="staged Swift file(s)" ;;
    --all)         scope=all;    scope_label="Swift file(s) in the repository" ;;
    -h | --help)
        sed -n '3,/^$/{s/^# \{0,1\}//;p;}' "$0"
        exit 0
        ;;
    *) fail "unknown option $1 (expected --staged, --all or --help)" ;;
esac

for tool in git mint; do
    command -v "$tool" >/dev/null 2>&1 || fail "$tool is not installed or not in PATH"
done

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || fail "not in a git repository"
cd "$repo_root"

# The file list is a temp file outside the repository, one path per line,
# read by both SwiftFormat and git. SwiftFormat resolves relative entries
# against the directory containing the list file, not the working directory
# (CommandLine.swift: parseFileList(source, in: fileListURL
# .deletingLastPathComponent().path)), so every entry is written as an
# absolute path. git emits the names NUL-separated so non-ASCII names arrive
# raw rather than escaped; --literal-pathspecs stops git from treating *, ?
# and [ in names as patterns. SwiftFormat itself treats "#" as the start of a
# comment and "," as a separator inside a list entry, so names containing
# those characters or a newline are not supported.
filelist=$(mktemp "${TMPDIR:-/tmp}/format-swift.XXXXXX")
hashes_before=$(mktemp "${TMPDIR:-/tmp}/format-swift.XXXXXX")
hashes_after=$(mktemp "${TMPDIR:-/tmp}/format-swift.XXXXXX")
trap 'rm -f "$filelist" "$hashes_before" "$hashes_after"' EXIT

# Prints the Swift files in scope, NUL-separated and relative to the root.
list_files() {
    case $scope in
        staged) git diff --cached --name-only -z --diff-filter=d -- '*.swift' ;;
        # --cached is the index, --others the untracked files, and
        # --exclude-standard drops what .gitignore ignores (.build/ and the
        # like). --deduplicate keeps a file staged more than once (a merge
        # with conflicts) to a single entry.
        all)    git ls-files -z --cached --others --exclude-standard --deduplicate -- '*.swift' ;;
    esac
}

# The index can list a file that was deleted from the working tree but not
# yet staged; SwiftFormat would fail on it, so only existing files are kept.
list_files |
    while IFS= read -r -d '' file; do
        if [ -f "$file" ]; then
            printf '%s/%s\n' "$repo_root" "$file"
        fi
    done > "$filelist"

if [ ! -s "$filelist" ]; then
    printf '🟣%s %s: no Swift files to format%s\n' "$magenta" "$script_name" "$reset"
    exit 0
fi

# Prints the listed files whose working tree differs from the index. git diff
# has no --pathspec-from-file, so the list is passed as arguments via xargs.
unstaged_in_list() {
    tr '\n' '\0' < "$filelist" |
        xargs -0 git --literal-pathspecs -c core.quotePath=false diff --name-only --
}

if [ "$scope" = staged ]; then
    dirty=$(unstaged_in_list)
    if [ -n "$dirty" ]; then
        printf '%s\n' "$dirty" | sed 's/^/  /' >&2
        fail "the Swift files above have unstaged changes; stage or stash them first"
    fi
fi

file_count=$(wc -l < "$filelist" | tr -d ' ')
info "formatting $file_count $scope_label"

# In --all scope git cannot tell SwiftFormat's changes from the developer's
# own, so the files are hashed before and after instead. hash-object writes
# one hash per input line in input order, so the two lists line up with the
# file list.
if [ "$scope" = all ]; then
    git hash-object --stdin-paths < "$filelist" > "$hashes_before"
fi

# SwiftFormat's config argument is optional, so it is kept in the positional
# parameters: "$@" expands to nothing when unset, which an empty array cannot
# do under set -u in bash 3.2.
if [ -f .swiftformat ]; then
    set -- --config .swiftformat
else
    info "no .swiftformat at the repository root, using SwiftFormat defaults"
    set --
fi

if ! mint run swiftformat --quiet "$@" --filelist "$filelist"; then
    fail "SwiftFormat failed"
fi

case $scope in
    staged)
        # The dirty check above guarantees that every listed file now
        # differing from the index is one SwiftFormat rewrote.
        reformatted=$(unstaged_in_list)
        ;;
    all)
        git hash-object --stdin-paths < "$filelist" > "$hashes_after"
        # Columns: hash before, hash after, absolute path. sub() strips the
        # first two columns so a tab inside a path survives; the root prefix
        # is then removed in bash, where ${line#"$prefix"} is a literal match.
        reformatted=$(paste "$hashes_before" "$hashes_after" "$filelist" |
            awk -F '\t' '$1 != $2 { sub(/^[^\t]*\t[^\t]*\t/, ""); print }' |
            while IFS= read -r line; do printf '%s\n' "${line#"$repo_root/"}"; done)
        ;;
esac

if [ -z "$reformatted" ]; then
    success "all $file_count $scope_label were already formatted"
    exit 0
fi

if [ "$scope" = staged ]; then
    git --literal-pathspecs add --pathspec-from-file="$filelist"
    success "reformatted and re-staged:"
else
    success "reformatted $(printf '%s\n' "$reformatted" | wc -l | tr -d ' ') file(s), left unstaged for review:"
fi
printf '%s%s%s\n' "$magenta" "$reformatted" "$reset"
