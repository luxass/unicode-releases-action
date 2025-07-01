#!/bin/bash

check_jq() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install jq to run this script."
        exit 1
    fi
}

bail() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    printf '::error::%s\n' "$*"
  else
    printf >&2 'error: %s\n' "$*"
  fi
  exit 1
}

warn() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    printf '::warning::%s\n' "$*"
  else
    printf >&2 'warning: %s\n' "$*"
  fi
}

info() {
  printf >&2 'info: %s\n' "$*"
}

fetch_with_retry() {
    local url="$1"
    local description="$2"
    local max_retries="${3:-3}"
    local delay="${4:-2}"
    
    for ((i=1; i<=max_retries; i++)); do
        info "🔄 fetching ${description} (attempt ${i}/${max_retries})"
        
        if response=$(curl -s --fail "${url}"); then
            echo "${response}"
            return 0
        fi
        
        if [[ $i -lt $max_retries ]]; then
            warn "failed to fetch ${description}, retrying in ${delay}s..."
            sleep "${delay}"
            delay=$((delay * 2))
        else
            bail "failed to fetch ${description} after ${max_retries} attempts"
        fi
    done
}

validate_json() {
    local data="$1"
    local description="$2"
    
    if ! echo "${data}" | jq empty 2>/dev/null; then
        bail "invalid JSON received from ${description}"
    fi
}

process_unicode_data() {
    local unicode_data="$1"
    local version_map="$2"
    local draft_version="$3"
    
    # get regular versions
    local regular_versions
    regular_versions=$(echo "${unicode_data}" | jq -c '[.[] |
        select(.name | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) |
        {version: .name, mappedVersion: .name, type: "regular"}]')
    
    # get update versions with mapped names
    local update_versions
    update_versions=$(echo "${unicode_data}" | jq -c --arg map "${version_map}" '
        [.[] |
         select(.name | test("^[0-9]+\\.[0-9]+-Update[0-9]*$")) |
         .name as $original |
         {
           version: (($map | fromjson) | to_entries | map(select(.value == $original)) | .[0].key // $original),
           mappedVersion: $original,
           type: "update"
         }
        ]
    ')
    
    # merge and filter out draft version
    echo "${update_versions} ${regular_versions}" | jq -s --arg draft "${draft_version}" '
        add | map(select(.version != $draft)) | sort_by(.version)'
}

generate_outputs() {
    local draft_version="$1"
    local latest_release="$2"
    local all_releases="$3"
    local ucd_releases="$4"
    
    # validate all output data
    if [[ -z "${draft_version}" ]]; then
        draft_version="unknown"
        warn "draft version is empty, using 'unknown'"
    fi
    
    if [[ -z "${latest_release}" ]]; then
        latest_release="unknown"
        warn "latest release is empty, using 'unknown'"
    fi
    
    # compact JSON output
    local compact_all_releases compact_ucd_releases
    compact_all_releases=$(echo "${all_releases}" | jq -c .)
    compact_ucd_releases=$(echo "${ucd_releases}" | jq -c .)
    
    # log summary
    info "📝 latest release: ${latest_release}"
    info "📝 latest draft: ${draft_version}"
    info "📦 all releases count: $(echo "${all_releases}" | jq length)"
    info "📦 UCD releases count: $(echo "${ucd_releases}" | jq length)"
    
    # write to GitHub output
    {
        printf 'current_draft=%s\n' "${draft_version}"
        printf 'latest_release=%s\n' "${latest_release}"
        printf 'all_releases=%s\n' "${compact_all_releases}"
        printf 'ucd_releases=%s\n' "${compact_ucd_releases}"
    } >>"${GITHUB_OUTPUT}"
    
    info "✅ outputs generated successfully"
}
