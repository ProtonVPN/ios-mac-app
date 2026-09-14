#!/bin/bash
#
# Checks the Localizable.strings files for malformed lines.
#
# Usage:
#   lint_translations.sh [FILE...]    defaults to every
#                                     libraries/Foundations/Strings/Sources/Strings/Resources/*.lproj/Localizable.strings
#
# A line must be one of: empty, a one-line block comment "/* ... */" with a
# space inside each delimiter, a translation "key" = "value"; or a line
# comment starting with //. Nothing may follow the "*/" that closes a block
# comment. Each offending line is printed as path:line: error: message, and
# the exit status is 1 when any was found.

if [ -z "${BASH_VERSION-}" ]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

# Explicit FILE arguments are resolved from the caller's directory; the
# default glob is resolved from the repository root.
if [ $# -eq 0 ]; then
    cd "$(git rev-parse --show-toplevel)"
    shopt -s nullglob
    set -- libraries/Foundations/Strings/Sources/Strings/Resources/*.lproj/Localizable.strings
    shopt -u nullglob
    if [ $# -eq 0 ]; then
        echo "lint_translations: no Localizable.strings files found" >&2
        exit 1
    fi
fi

# grep -a treats the files as text whatever the locale, so non-ASCII
# translations never turn into "Binary file matches" instead of line output.
# Rule 1 lists lines that match none of the allowed shapes (grep -v).
# Rule 2 lists lines where a closed block comment is followed by anything,
# including trailing whitespace, and gives them a more specific message than
# rule 1 would.
allowed_line='^($|/\* .* \*/$|".*" = ".*";$|//)'
leaky_block_comment='^/\*.*\*/.'

# Reads "line:text" pairs from grep -n and prints one diagnostic per line.
report() {
    local file=$1 message=$2 line
    while IFS=: read -r line _; do
        printf '%s:%s: error: %s\n' "$file" "$line" "$message"
    done
}

# grep exits 1 when nothing matched, so the assignment's status says whether
# there is anything to report.
status=0
for file in "$@"; do
    if [ ! -r "$file" ]; then
        echo "lint_translations: cannot read $file" >&2
        status=1
        continue
    fi
    if matches=$(grep -a -n -v -E "$allowed_line" "$file"); then
        status=1
        printf '%s\n' "$matches" | report "$file" "Each line should be either a comment or translation"
    fi
    if matches=$(grep -a -n -E "$leaky_block_comment" "$file"); then
        status=1
        printf '%s\n' "$matches" | report "$file" "Block comments should not have any characters after the closing brace"
    fi
done

if [ "$status" -eq 0 ]; then
    echo "lint_translations: $# file(s) OK"
fi
exit "$status"
