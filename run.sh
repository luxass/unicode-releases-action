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

# fetch the unicode data
if ! UNICODE_DATA=$(curl -s "${BASE_URL}/proxy"); then
    bail "failed to fetch unicode data"
fi

# fetch the draft README
if ! DRAFT_DATA=$(curl -s "${BASE_URL}/proxy/draft/ReadMe.txt"); then
    bail "failed to fetch draft data"
fi

# get all release names and filter for semver versions
RELEASES=$(echo "${UNICODE_DATA}" | jq -c '[.[] | select(.name | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name]')
LATEST_RELEASE=$(echo "${UNICODE_DATA}" | jq -r '.[] | select(.name | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) | select(.draft | not) | .name' | sort -V | tail -n1)

# extract draft version from README.txt
DRAFT_VERSION=$(echo "${DRAFT_DATA}" | grep -o "Version [0-9]\+\.[0-9]\+\.[0-9]\+" | head -n1 | cut -d' ' -f2)

info "📝 Latest release: ${LATEST_RELEASE}"
info "📝 Latest draft: ${DRAFT_VERSION}"
info "📦 All releases: ${RELEASES}"

{
  printf 'current_draft=%s\n' "${DRAFT_VERSION}"
  printf 'latest_release=%s\n' "${LATEST_RELEASE}"
  printf 'all_releases=%s\n' "${RELEASES}"
} >>"${GITHUB_OUTPUT}"


