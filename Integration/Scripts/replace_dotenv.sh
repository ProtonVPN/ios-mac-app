#!/bin/bash -e
# This script takes a dotenv file as an argument, and replaces the referenced variables in any other files passed.

DOTENVS=()
REPLACE=()

SCRIPT_DIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
REPO_PATH=$(cd "${SCRIPT_DIR}/../.." && pwd) # script is in Integration/Scripts
MYSELF=$0

function print_usage() {
    echo "Usage:"
    echo "$MYSELF [-e <dotenv>...] -- <source files>"
    echo ""
    echo "dotenv: the path to an env file. May specify more than one as long as '-e' precedes each path."
    echo "source file: any file which may contain references to the variables contained in the dotenv files."
}

function die() {
    local code=$1
    local msg=$2

    echo "Error: $msg." > /dev/stderr

    # taken from `man sysexits`
    case "$code" in
        usage) print_usage > /dev/stderr; exit 64 ;;
        dataerr) exit 65 ;;
        noinput) exit 66 ;;
        unavailable) exit 69 ;;
        software) exit 70 ;;
        protocol) exit 76 ;;
    esac
}

function cmd_replace() {
    VARS=""
    for dotenv in "${DOTENVS[@]}"; do
        if [ ! -f "$dotenv" ]; then
            die dataerr "env file '$dotenv' not found"
        fi

        # envsubst wants a single argument containing all of the variables
        # we want to replace in shell-format, e.g., '$FOO $BAR $FIZZ $BUZZ'.
        # Each line (that isn't an empty line or a comment) looks like
        # 'export VALUE=value', so we set the field separator to be either a
        # space or an equals sign and print the second item of each line,
        # preceded by a $ and ending with a space.
        VARS+=$(grep -v '^\(#\|\s*$\)' < "$dotenv" | awk -F ' |\=' '{printf "$"$2" " }')

        source "$dotenv"
    done

    echo "Will replace these values:"
    echo "$VARS" | tr " " "\n"
    for file in "${REPLACE[@]}"; do
        if [ ! -f "$file" ]; then
            die dataerr "source file '$file' not found"
        fi

        echo "Replacing strings in ${file}..."
        envsubst "$VARS" < "$file" | sponge "$file"
    done
}

if [ ! -x "$(command -v envsubst)" ]; then
    die unavailable "The program 'envsubst' is not installed. Please run 'brew install gettext'"
fi

if [ ! -x "$(command -v sponge)" ]; then
    die unavailable "The program 'sponge' is not installed. Please run 'brew install moreutils'"
fi

while getopts ":he:" arg; do
    case "$arg" in
        e) DOTENVS+=("$OPTARG") ;;
        h) print_usage; exit 0 ;;
        ?) die usage "unknown option -$OPTARG" ;;
        --) break ;;
    esac
done
shift $(($OPTIND - 1))

REPLACE+=("$@")

if [ ${#REPLACE[@]} -eq 0 ] || [ ${#DOTENVS[@]} -eq 0 ]; then
    die usage "must specify at least one dotenv file and one source file"
fi

cmd_replace
