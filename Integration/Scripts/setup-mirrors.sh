#!/bin/bash
set -euo pipefail

# setup-mirrors.sh
#
# Configures SPM mirrors so binary framework fetches are redirected from a
# public download URL to an internal Nexus mirror, without ever hardcoding
# the internal Nexus host in this (public) repo.
#
# Usage:
#   ./setup-mirrors.sh

configure_mirror() {
  local package_swift="$1"
  local framework_name="$2"
  local original_prefix="$3"

  if [ ! -f "$package_swift" ]; then
    echo "Error: Package.swift not found at: $package_swift"
    return 1
  fi

  if [ -z "${CI_NEXUS_URL:-}" ]; then
    echo "Error: CI_NEXUS_URL is not set."
    return 1
  fi

  # With the assumption that all internal mirrors live under the same Nexus repository convention:
  #   ${CI_NEXUS_URL}/repository/vpn-release-candidates/<name>/
  #    where <name> is the framework name with the .xcframework suffix removed.
  local nexus_component="${framework_name%.xcframework}"
  local mirror_prefix="${CI_NEXUS_URL%/}/repository/vpn-release-candidates/${nexus_component}/"

  # Find the URL directly by matching original_prefix
  #
  # Note: if the manifest has a dead #if false / #else block with a
  # duplicate url, this may match more than
  # once — `head -1` just takes the first, which is fine as long as both
  # occurrences are actually identical.
  local original_url
  original_url=$(grep -oE "${original_prefix}[^\"]+" "$package_swift" | head -1) || true

  if [ -z "$original_url" ]; then
    echo "Error: could not find a URL starting with '${original_prefix}' in ${package_swift}"
    return 1
  fi

  if [ -z "$original_url" ]; then
    echo "Error: could not find a URL starting with '${original_prefix}' near '${framework_name}' in ${package_swift}"
    return 1
  fi

  local mirror_url="${mirror_prefix}${original_url#"$original_prefix"}"

  local target_dir
  target_dir="$(dirname "$package_swift")"

  echo "Configuring mirror for: ${framework_name}"
  echo "  Manifest: ${package_swift}"
  echo "  Original: ${original_url}"
  echo "  Mirror:   [hidden]"

  (
    cd "$target_dir"

    if swift package config unset-mirror --original "${original_url}" > /dev/null 2>&1; then
      echo "  Removed existing mirror entry for this URL before re-adding."
    fi

    swift package config set-mirror \
      --original "${original_url}" \
      --mirror   "${mirror_url}"

    echo "  Mirror configured successfully."
  )
}

# ---------------------------------------------------------------------------
# Hardcoded invocations. Add invoke the method for each framework
# that needs to be mirrored.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
 
configure_mirror \
  "${REPO_ROOT}/libraries/Core/NEProviders/Package.swift" \
  "protun.xcframework" \
  "https://vpn.protondownload.com/download/protun/"
