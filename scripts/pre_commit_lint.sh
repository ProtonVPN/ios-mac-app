#!/bin/bash -e

SCRIPT_NAME="$0"
SCRIPT_DIR=$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd "$SCRIPT_DIR/.." # project directory

PRE_COMMIT_FILE="$PWD/.git/hooks/pre-commit"

if [[ "$1" == "setup" ]]; then
    if [ -f "$PRE_COMMIT_FILE" ]; then
        echo "Found pre-commit hook. Adding our script."
        echo -e "\n./scripts/pre_commit_lint.sh" >> "$PRE_COMMIT_FILE"

    else
        echo "Pre-commit hook not found. Will create it now."

        echo "#!/bin/bash" > "$PRE_COMMIT_FILE"
        echo "./scripts/pre_commit_lint.sh" >> "$PRE_COMMIT_FILE"
        chmod a+x "$PRE_COMMIT_FILE"
    fi

    echo "Success! From now on before each commit swiftlint will check all modified files."
    exit 0
fi

# Script "inspired" by https://samwize.com/2022/04/22/run-swiftlint-in-pre-commit-hook/

SWIFT_LINT=./Pods/SwiftLint/swiftlint

if [[ -e "${SWIFT_LINT}" ]]; then
    # Export files in SCRIPT_INPUT_FILE_$count to lint against later
    count=0
    while IFS= read -r file_path; do
        export SCRIPT_INPUT_FILE_$count="$file_path"
        count=$((count + 1))
    done < <(git diff --name-only --cached --diff-filter=d | grep ".swift$")
    export SCRIPT_INPUT_FILE_COUNT=$count

    if [ "$count" -eq 0 ]; then
        echo "No files to lint!"
        exit 0
    fi

    echo "Found $count lintable files! Linting now.."
    $SWIFT_LINT --use-script-input-files --strict --config .swiftlint.yml
    RESULT=$? # swiftline exit value is number of errors

    if [ $RESULT -eq 0 ]; then
        echo "🎉  Well done. No violation."
    fi
    exit $RESULT
else
    echo "⚠️  WARNING: SwiftLint not found in $SWIFT_LINT"
    echo "⚠️  You might want to edit .git/hooks/pre-commit to locate your swiftlint"
    exit 0
fi

