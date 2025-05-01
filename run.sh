#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -CeEuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# check for jq
check_jq

BASE_URL="https://unicode-proxy.ucdjs.dev"

info "🔍 checking for new releases"
info "🔗 base url: ${BASE_URL}"


extract_from_readme() {
    local data="$1"
    echo "${data}" | grep -o "Version [0-9]\+\.[0-9]\+\.[0-9]\+" | head -n1 | cut -d' ' -f2
}

# fetch the unicode data
if ! UNICODE_DATA=$(curl -s "${BASE_URL}/proxy"); then
    bail "failed to fetch unicode data"
fi

# fetch the draft README
if ! DRAFT_DATA=$(curl -s "${BASE_URL}/proxy/draft/ReadMe.txt"); then
    bail "failed to fetch draft data"
fi

# fetch the latest release README
if ! LATEST_DATA=$(curl -s "${BASE_URL}/proxy/UCD/latest/ReadMe.txt"); then
    bail "failed to fetch latest release data"
fi

DRAFT_VERSION=$(extract_from_readme "${DRAFT_DATA}")
LATEST_RELEASE=$(extract_from_readme "${LATEST_DATA}")

# get all release names and filter for semver versions
RELEASES=$(echo "${UNICODE_DATA}" | jq -c '[.[] | select(.name | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name]')

info "📝 Latest release: ${LATEST_RELEASE}"
info "📝 Latest draft: ${DRAFT_VERSION}"
info "📦 All releases: ${RELEASES}"

{
  printf 'current_draft=%s\n' "${DRAFT_VERSION}"
  printf 'latest_release=%s\n' "${LATEST_RELEASE}"
  printf 'all_releases=%s\n' "${RELEASES}"
} >>"${GITHUB_OUTPUT}"


