#!/bin/bash
#
# Lints the repository's Swift sources with SwiftLint and writes a Code
# Climate report for GitLab.
#
# Usage:
#   code_quality.sh [--fail-on-violations] [REPORT]
#
#   REPORT is the output path, default codequality_report.json in the
#   repository root. Violations are the report's content, not a failure: the
#   script exits 0 whether or not any were found, so the CI job that uploads
#   the report keeps running. With --fail-on-violations it exits 2 instead
#   when the report is non-empty, for use as a check. SwiftLint failing to
#   run at all exits 1 in both cases.
#
# Every tracked Swift file is linted in one SwiftLint run started from the
# repository root. Taking the file list from git means ignored directories
# (.build/ and the package checkouts inside it) are never scanned, and running
# from the root means the report's paths are repository-relative as GitLab
# needs them, with no per-module runs and no path rewriting.
#
# Requires SwiftLint 0.57.1 or later (for --use-script-input-file-lists), run
# through mint from the repository's Mintfile.

# Re-run under bash when started as `sh script`. This block is the only code
# the other shell reads.
if [ -z "${BASH_VERSION-}" ]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

# Homebrew's directories, for shells started without the login PATH.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

script_name=$(basename "$0")
info() { printf '%s: %s\n' "$script_name" "$1" >&2; }
fail() { printf '%s: ERROR: %s\n' "$script_name" "$1" >&2; exit 1; }

fail_on_violations=false
report=codequality_report.json
while [ $# -gt 0 ]; do
    case $1 in
        -h | --help)
            sed -n '3,/^$/{s/^# \{0,1\}//;p;}' "$0"
            exit 0
            ;;
        --fail-on-violations) fail_on_violations=true ;;
        -*) fail "unknown option $1" ;;
        *) report=$1 ;;
    esac
    shift
done

for tool in git mint; do
    command -v "$tool" >/dev/null 2>&1 || fail "$tool is not installed or not in PATH"
done

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || fail "not in a git repository"
cd "$repo_root"

# A relative REPORT is resolved from the repository root, like every other
# path in this script, not from where the script was started.
mkdir -p "$(dirname "$report")"
[ -f Mintfile ] || fail "no Mintfile at $repo_root"
[ -f .swiftlint.yml ] || fail "no .swiftlint.yml at $repo_root"

# CI sets MINT_PATH and MINT_LINK_PATH to paths relative to the checkout so
# the mint cache can be kept between jobs; anchor those at the repository
# root, since this script may be started from any directory. Unset (mint's
# default, ~/.mint) and absolute values are left alone. The previous version
# prefixed unconditionally, which for an unset variable produced
# "$PWD/" and made mint install and build its packages into the repository.
for var in MINT_PATH MINT_LINK_PATH; do
    value=${!var-}
    if [ -n "$value" ] && [ "${value#/}" = "$value" ]; then
        export "$var=$repo_root/$value"
    fi
done

# SwiftLint reads the files to lint from an .xcfilelist named by environment
# variables (--use-script-input-file-lists), one absolute path per line. The
# list is built from the git index so untracked and ignored files are never
# linted. Files deleted from the working tree but still in the index are
# skipped; SwiftLint would fail to read them.
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/lint-swift.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT
filelist=$tmpdir/files.xcfilelist

git ls-files -z -- '*.swift' |
    while IFS= read -r -d '' file; do
        if [ -f "$file" ]; then
            printf '%s/%s\n' "$repo_root" "$file"
        fi
    done > "$filelist"

file_count=$(wc -l < "$filelist" | tr -d ' ')
if [ "$file_count" -eq 0 ]; then
    fail "no tracked Swift files found"
fi
info "linting $file_count Swift files"

# --force-exclude applies the config's `excluded` entries to files given
# explicitly; without it SwiftLint only applies them when it discovers files
# itself.
status=0
SCRIPT_INPUT_FILE_LIST_COUNT=1 SCRIPT_INPUT_FILE_LIST_0=$filelist \
    mint run -m Mintfile -s swiftlint lint \
        --config .swiftlint.yml \
        --use-script-input-file-lists \
        --force-exclude \
        --strict \
        --reporter codeclimate \
        > "$report" || status=$?

case $status in
    0 | 2) ;;
    *) fail "SwiftLint exited with status $status (report at $report may be incomplete)" ;;
esac

# The report is the source of truth for the count. SwiftLint's exit status
# only tells about error-severity violations, so without jq the count is
# unknown and only that weaker signal is available.
if command -v jq >/dev/null 2>&1; then
    violations=$(jq length "$report")
    if [ "$violations" -eq 0 ]; then
        info "no violations, report written to $report"
        exit 0
    fi
    info "$violations violations, report written to $report"
    has_violations=true
else
    info "report written to $report (install jq for a violation count)"
    [ "$status" -eq 2 ] && has_violations=true || has_violations=false
fi

if [ "$fail_on_violations" = true ] && [ "$has_violations" = true ]; then
    exit 2
fi
exit 0
