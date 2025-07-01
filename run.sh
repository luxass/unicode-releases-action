#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -CeEuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# check for jq
check_jq

if [[ -z "${INPUT_API_BASE_URL:-}" ]]; then
  API_BASE_URL="https://api.ucdjs.dev/api"
else
  case "${INPUT_API_BASE_URL}" in
    */api) API_BASE_URL="${INPUT_API_BASE_URL}" ;;
    *)     API_BASE_URL="${INPUT_API_BASE_URL}/api" ;;
  esac
fi

PROXY_BASE_URL="${INPUT_PROXY_BASE_URL:-"https://unicode-proxy.ucdjs.dev"}"

info "🔍 checking for new releases"
info "🔗 proxy base url: ${PROXY_BASE_URL}"
info "🔗 api base url: ${API_BASE_URL}"

extract_from_readme() {
    local data="$1"
    echo "${data}" | grep -o "Version [0-9]\+\.[0-9]\+\.[0-9]\+" | head -n1 | cut -d' ' -f2
}


# fetch all required data with retry logic
UNICODE_DATA=$(fetch_with_retry "${PROXY_BASE_URL}" "unicode data")
validate_json "${UNICODE_DATA}" "unicode data"

UNICODE_VERSIONS=$(fetch_with_retry "${API_BASE_URL}/v1/unicode-versions" "all versions")
validate_json "${UNICODE_VERSIONS}" "all versions"

DRAFT_DATA=$(fetch_with_retry "${PROXY_BASE_URL}/draft/ReadMe.txt" "draft README")

LATEST_DATA=$(fetch_with_retry "${PROXY_BASE_URL}/UCD/latest/ReadMe.txt" "latest release README")

VERSION_MAP=$(fetch_with_retry "${API_BASE_URL}/v1/unicode-versions/mappings" "version mappings")
validate_json "${VERSION_MAP}" "version mappings"


DRAFT_VERSION=$(extract_from_readme "${DRAFT_DATA}")
LATEST_RELEASE=$(extract_from_readme "${LATEST_DATA}")

# validate extracted versions
if [[ -z "${DRAFT_VERSION}" ]]; then
    warn "could not extract draft version from README"
fi

if [[ -z "${LATEST_RELEASE}" ]]; then
    warn "could not extract latest release version from README"
fi

# process unicode releases with improved logic
UCD_RELEASES=$(process_unicode_data "${UNICODE_DATA}" "${VERSION_MAP}" "${DRAFT_VERSION}")
validate_json "${UCD_RELEASES}" "processed UCD releases"


generate_outputs "${DRAFT_VERSION}" "${LATEST_RELEASE}" "${UNICODE_VERSIONS}" "${UCD_RELEASES}"


