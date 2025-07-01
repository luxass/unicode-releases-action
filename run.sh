#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -CeEuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# check for jq
check_jq

API_BASE_URL="${INPUT_API_BASE_URL:-"https://api.ucdjs.dev"}/api"
PROXY_BASE_URL="${INPUT_PROXY_BASE_URL:-"https://unicode-proxy.ucdjs.dev"}"

info "🔍 checking for new releases"
info "🔗 proxy base url: ${PROXY_BASE_URL}"
info "🔗 api base url: ${API_BASE_URL}"

extract_from_readme() {
    local data="$1"
    echo "${data}" | grep -o "Version [0-9]\+\.[0-9]\+\.[0-9]\+" | head -n1 | cut -d' ' -f2
}

# fetch the unicode data
if ! UNICODE_DATA=$(curl -s "${PROXY_BASE_URL}"); then
    bail "failed to fetch unicode data"
fi

if ! UNICODE_VERSIONS=$(curl -s "${API_BASE_URL}/v1/unicode-versions"); then
    bail "failed to fetch all versions"
fi

# fetch the draft README
if ! DRAFT_DATA=$(curl -s "${PROXY_BASE_URL}/draft/ReadMe.txt"); then
    bail "failed to fetch draft data"
fi

# fetch the latest release README
if ! LATEST_DATA=$(curl -s "${PROXY_BASE_URL}/UCD/latest/ReadMe.txt"); then
    bail "failed to fetch latest release data"
fi

# fetch version mappings
if ! VERSION_MAP=$(curl -s "${API_BASE_URL}/v1/unicode-versions/mappings"); then
    bail "failed to fetch version mappings"
fi

DRAFT_VERSION=$(extract_from_readme "${DRAFT_DATA}")
LATEST_RELEASE=$(extract_from_readme "${LATEST_DATA}")

# get regular versions
REGULAR_VERSIONS=$(echo "${UNICODE_DATA}" | jq -c '[.[] |
  select(.name | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) |
  {version: .name, mappedVersion: .name}]')

# Get update versions as new objects with mapped name but original ucd
UPDATE_VERSIONS=$(echo "${UNICODE_DATA}" | jq -c --arg map "${VERSION_MAP}" '
  [.[] |
   select(.name | test("^[0-9]+\\.[0-9]+-Update[0-9]*$")) |
   .name as $original |
   {
     version: (($map | fromjson) | to_entries | map(select(.value == $original)) | .[0].key),
     mappedVersion: $original
   }
  ]
')

# Merge both lists into final releases
MERGED_UCD_RELEASES=$(echo "${UPDATE_VERSIONS} ${REGULAR_VERSIONS}" | jq -s 'add')

# remove the draft release from the releases list
UCD_RELEASES=$(echo "${MERGED_UCD_RELEASES}" | jq -c --arg draft "${DRAFT_VERSION}" '[.[] | select(.version != $draft)]')

info "📝 Latest release: ${LATEST_RELEASE}"
info "📝 Latest draft: ${DRAFT_VERSION}"
info "📦 All releases: ${UNICODE_VERSIONS}"
info "📦 Releases with UCD: ${UCD_RELEASES}"

{
  printf 'current_draft=%s\n' "${DRAFT_VERSION}"
  printf 'latest_release=%s\n' "${LATEST_RELEASE}"
  printf 'all_releases=%s\n' "${UNICODE_VERSIONS}"
  printf 'ucd_releases=%s\n' "${UCD_RELEASES}"
} >>"${GITHUB_OUTPUT}"


