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
