#!/bin/bash

if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    MAGENTA=$(tput setaf 5)
    YELLOW=$(tput setaf 3)
    BOLD=$(tput bold)
    ENDCOLOR=$(tput sgr0)
else
    RED=""
    GREEN=""
    MAGENTA=""
    YELLOW=""
    BOLD=""
    ENDCOLOR=""
fi

set -e
set -u
set -o pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
files_to_format="files_to_format"

function cleanup() {
    rm -f files_to_format
    exit 0
}

function error_exit() {
    printf "🔴${RED}${BOLD} $script_name: ERROR: %s${ENDCOLOR}\n" "$1" >&2
    exit 1
}

function check_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        error_exit "$1 is not installed or not in PATH. Please install $1 first."
    fi
}

function print_info() {
    printf "ℹ️ ${YELLOW} $script_name: %s${ENDCOLOR}\n" "$1"
}

function print_success() {
    printf "🟢${GREEN}${BOLD} $script_name: %s${ENDCOLOR}\n" "$1"
}

trap cleanup 0 1 2 EXIT

# Check for required tools
print_info "Checking required tools..."
check_tool "git"
check_tool "mint"

# Verify we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    error_exit "Not in a git repository"
fi

git_root_directory=$(git rev-parse --show-toplevel)
config="${git_root_directory}/.swiftformat"

# Check if SwiftFormat config exists
if [ ! -f "$config" ]; then
    print_info "SwiftFormat config not found at $config, using default settings"
    config=""
else
    print_info "Using SwiftFormat config: $config"
fi

# Get staged Swift files
staged_swift_files=$(git diff --diff-filter=d --staged --name-only | grep -E '\.swift$' || true)

if [ -z "$staged_swift_files" ]; then
    printf "🟣${MAGENTA} $script_name: No Swift files to format${ENDCOLOR}\n"
    printf "\n"
    exit 0
fi

# Count files for better user feedback
file_count=$(echo "$staged_swift_files" | wc -l | tr -d ' ')
print_info "Found $file_count Swift file(s) to format"

# Write files to temporary file
echo "$staged_swift_files" > "$files_to_format"

# Run SwiftFormat
print_info "Running SwiftFormat..."
if [ -n "$config" ]; then
    mint run swiftformat --quiet --config $config --filelist $files_to_format
else
    mint run swiftformat --quiet --filelist $files_to_format
fi
formatting_result=$?

# Re-stage the formatted files
if [ $formatting_result -eq 0 ]; then
    while IFS= read -r file; do
        git add "$file"
    done < "$files_to_format"
    
    print_success "Successfully formatted the following files:"
    printf "${MAGENTA}%s${ENDCOLOR}\n" "$staged_swift_files"
    printf "\n${GREEN}${BOLD}✅ All Swift files have been formatted and re-staged!${ENDCOLOR}\n"
else
    error_exit "SwiftFormat failed with exit code $formatting_result"
fi

exit $formatting_result
