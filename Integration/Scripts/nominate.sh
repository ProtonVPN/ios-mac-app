#!/bin/bash -e
#
# This is an interactive script for nominating releases for promotion, and for verifying those nominations.

LHC_TRAIN=
REFERENCE=
DONT_SYNC=false
ALLOW_EXP=false
LHC_REFS_ATTR=proton/attrs
TRUST_LEVEL=TRUST_FULLY

TRAILER=Nominated-By

SCRIPT_DIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
REPO_PATH=$(cd "${SCRIPT_DIR}/../.." && pwd) # script is in Integration/Scripts
MYSELF=$0

function print_usage() {
    echo "Usage:"
    echo "$MYSELF add [-a <attribute>] [-t <train>] [-C <repo path>] [-S] [-v <version> | <reference>]"
    echo "$MYSELF verify [-a <attribute>] [-t <train>] [-C <repo path>] [-T <trust level>] [-X] [-S] [-v <version> | <reference>]"
    echo ""
    echo "-S (optional): don't sync tags or notes before or after the operation(s)."
    echo "-X (optional, DANGER): accept signatures from expired keys."
    echo "attribute: the name of the attribute to use. Defaults to 'Nominated-By'."
    echo "train: one of the supported trains for this repo. Omit to use the default, if one is set."
    echo "repo path: path to the repository. Useful for submodules in a project."
    echo "version/ref: the version or reference on which to add the nomination attribute."
    echo "trust level (DANGER): trust level for the nomination signature. Should be one of:"
    echo -e "\tundefined: no explicit trust on the key used for nominating the release."
    echo -e "\tmarginal: signer of key used for nomination understands the implications of key signing."
    echo -e "\tfull (default): signature of key used for nomination would be as good as your own."
    echo -e "\tThe 'never' value is not allowed; any explicitly untrusted key will result in verification failure."
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
        software) exit 70 ;;
        protocol) exit 76 ;;
    esac
}

function fetch() {
    local tagref

    if [ -n "$VERSION" ]; then
        tagref="+refs/tags/$REFERENCE:refs/tags/$REFERENCE"
    fi

    git fetch origin "+refs/notes/${LHC_REFS_ATTR}:refs/notes/${LHC_REFS_ATTR}" "$tagref"
}

function push() {
    git push origin "refs/notes/$LHC_REFS_ATTR"
}

function set_trailer() {
    local train_args=()
    local author="$(git config user.name) <$(git config user.email)>"

    if [ -n "$LHC_TRAIN" ]; then
        train_args=("--train" "$LHC_TRAIN")
    fi

    echo "Adding nomination..."

    mint run -s \
        git-lhc attr add "${train_args[@]}" "${TRAILER}=${author}" "$REFERENCE"
}

function check_trailer() {
    local train_args=()
    if [ -n "$LHC_TRAIN" ]; then
        train_args=("--train" "$LHC_TRAIN")
    fi

    NOTE_COMMIT=$(
        mint run -s \
            git-lhc attr log "${train_args[@]}" "$TRAILER" "$REFERENCE" | \
            head -n 2 | \
            grep -A 1 "^\+$TRAILER: " | \
            tail -n 1 |
            grep -o "^[0-9a-f][0-9a-f]*" || true
    )

    if [ -z "$NOTE_COMMIT" ]; then
        die noinput "missing nomination attribute '$TRAILER'"
    fi

    echo "Found nomination attribute '$TRAILER'."

    local sig
    sig=$(git verify-commit --raw "$NOTE_COMMIT" 2> /dev/stdout | cut -d ' ' -f 2)

    if ! grep GOODSIG <<< "$sig" > /dev/null; then
        die dataerr "invalid signature for nomination"
    fi

    if [ "$ALLOW_EXP" == false ] && ! grep VALIDSIG <<< "$sig" > /dev/null; then
        die dataerr "signature for nomination has expired"
    fi

    if grep TRUST_NEVER <<< "$sig" > /dev/null; then
        die dataerr "signature for nomination is explicitly untrusted"
    fi

    local sig_trust
    sig_trust=$(grep TRUST_ <<< "$sig" | tail -n 1)

    local trusted=false
    case "$sig_trust" in
        TRUST_UNDEFINED)
            if [ "$TRUST_LEVEL" == "$sig_trust" ]; then
                trusted=true
            fi
            ;;
        TRUST_MARGINAL)
            if [ "$TRUST_LEVEL" == "$sig_trust" ] || [ "$TRUST_LEVEL" == "TRUST_UNDEFINED" ] ; then
                trusted=true
            fi
            ;;
        TRUST_FULLY)
            if [ "$TRUST_LEVEL" == "$sig_trust" ] || [ "$TRUST_LEVEL" == "TRUST_MARGINAL" ] || [ "$TRUST_LEVEL" == "TRUST_UNDEFINED" ] ; then
                trusted=true
            fi
            ;;
        *) die protocol "unknown trust level '$sig_trust' for key in signature" ;;
    esac

    if [ "$trusted" != "true" ]; then
        die dataerr "attribute signature trust level '$sig_trust' is insufficient for specified trust level '$TRUST_LEVEL'"
    fi

    if [ "$TRUST_LEVEL" == "$sig_trust" ]; then
        echo "Nomination valid with $TRUST_LEVEL."
    else
        echo "Nomination valid with $TRUST_LEVEL. (Actual trust level is $sig_trust.)"
    fi
}

function cmd_add() {
    [ "$DONT_SYNC" == "true" ] || fetch
    set_trailer
    [ "$DONT_SYNC" == "true" ] || push
}

function cmd_verify() {
    [ "$DONT_SYNC" == "true" ] || fetch
    check_trailer
}

COMMAND="$1"
shift

while getopts ":ht:C:a:v:T:S" arg; do
    case "$arg" in
        a) TRAILER="$OPTARG" ;;
        v) VERSION="$OPTARG" ;;
        t) LHC_TRAIN="$OPTARG" ;;
        C) REPO_PATH="$OPTARG" ;;
        S) DONT_SYNC="true" ;;
        X)
            if [ "$COMMAND" != "verify" ]; then
                die usage "can only use -X with verify"
            fi

            ALLOW_EXP="true"
            ;;
        T)
            if [ "$COMMAND" != "verify" ]; then
                die usage "can only use -T with verify"
            fi

            case $OPTARG in
                undefined) TRUST_LEVEL=TRUST_UNDEFINED ;;
                marginal) TRUST_LEVEL=TRUST_MARGINAL ;;
                full) TRUST_LEVEL=TRUST_FULLY ;;
                *) die usage "invalid trust level $OPTARG" ;;
            esac
            ;;
        h) print_usage; exit 0 ;;
        ?) die usage "unknown option -$OPTARG." ;;
        --) break ;;
    esac
done
shift $(($OPTIND - 1))

REFERENCE=$1
if [ -n "$VERSION" ]; then
    if [ -n "$REFERENCE" ]; then
        die usage "can't specify '$REFERENCE' with a version"
    fi

    if [ -n "$LHC_TRAIN" ]; then
        REFERENCE="${LHC_TRAIN}/${VERSION}"
    else
        REFERENCE="$VERSION"
    fi
fi

cd "$REPO_PATH"

case "$COMMAND" in
    add) cmd_add ;;
    verify) cmd_verify ;;
    -h|help) print_usage; exit 0;;
    *) die usage "unknown command ${COMMAND}" ;;
esac
