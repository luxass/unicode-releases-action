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
    local connect_timeout="${5:-10}"
    local max_time="${6:-30}"

    local i response curl_status curl_error
    local curl_error_file

    for ((i=1; i<=max_retries; i++)); do
        info "🔄 fetching ${description} (attempt ${i}/${max_retries}) (url: ${url})"

        curl_error_file="$(mktemp)"
        if response=$(curl \
            --silent \
            --show-error \
            --fail \
            --location \
            --connect-timeout "${connect_timeout}" \
            --max-time "${max_time}" \
            -A "unicode-releases-action (https://github.com/luxass/unicode-releases-action)" \
            "${url}" \
            2>|"${curl_error_file}"); then

            rm -f "${curl_error_file}"

            if [[ -z "${response}" ]]; then
                warn "received empty response for ${description}"
            else
                info "✅ fetched ${description} (${#response} bytes)"
            fi

            echo "${response}"
            return 0
        else
            curl_status=$?
            curl_error="$(cat "${curl_error_file}")"
            rm -f "${curl_error_file}"

            if [[ -n "${curl_error}" ]]; then
                warn "failed to fetch ${description} (curl exit ${curl_status}): ${curl_error}"
            else
                warn "failed to fetch ${description} (curl exit ${curl_status})"
            fi

            if [[ $i -lt $max_retries ]]; then
                warn "retrying in ${delay}s..."
                sleep "${delay}"
                delay=$((delay * 2))
            else
                bail "failed to fetch ${description} after ${max_retries} attempts"
            fi
        fi
    done
}

extract_from_readme() {
    local data="$1"
    echo "${data}" | grep -o "Version [0-9]\+\.[0-9]\+\.[0-9]\+" | head -n1 | cut -d' ' -f2
}

validate_json() {
    local data="$1"
    local description="$2"

    if ! echo "${data}" | jq empty 2>/dev/null; then
        bail "invalid JSON received from ${description}"
    fi
}
