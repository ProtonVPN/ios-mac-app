#!/bin/bash

# Format all xctestplan files by sorting testTargets by target.name
# Only processes files in:
# - apps/{ios,macos,tvos}/TestPlans/*.xctestplan
# - libraries/{Core,Features,Foundations,Shared}/*/Tests/*.xctestplan

set -e

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Warning: jq is not installed. Please install jq to format xctestplan files."
    echo "Install with: brew install jq"
    exit 0
fi

# Get the repository root directory
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

echo "Formatting xctestplan files..."

# Process all test plans in apps and libraries directories
find \
    ./apps/ios/TestPlans \
    ./apps/macos/TestPlans \
    ./apps/tvos/TestPlans \
    ./libraries/Core/*/Tests \
    ./libraries/Features/*/Tests \
    ./libraries/Foundations/*/Tests \
    ./libraries/Shared/*/Tests \
    -name "*.xctestplan" -type f \
    -exec sh -c 'jq ".testTargets |= sort_by(.target.name)" "$1" > "$1.tmp" && mv -f "$1.tmp" "$1"' _ {} \;

echo "Done! All xctestplan files have been formatted."
