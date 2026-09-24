#!/bin/sh
# sranime-cli network module — retry logic and connectivity helpers

SRANIME_CLI_MAX_RETRIES="${SRANIME_CLI_MAX_RETRIES:-3}"
SRANIME_CLI_RETRY_DELAY="${SRANIME_CLI_RETRY_DELAY:-2}"

retry_curl() {
    _attempt=1
    while [ "$_attempt" -le "$SRANIME_CLI_MAX_RETRIES" ]; do
        if _output=$("$@" 2>&1); then
            printf '%s' "$_output"
            return 0
        fi
        _exit_code=$?
        if [ "$_attempt" -lt "$SRANIME_CLI_MAX_RETRIES" ]; then
            printf "\33[2K\r\033[1;33m  Retry %d/%d in %ds...\033[0m" \
                "$_attempt" "$SRANIME_CLI_MAX_RETRIES" "$SRANIME_CLI_RETRY_DELAY" >&2
            sleep "$SRANIME_CLI_RETRY_DELAY"
        fi
        _attempt=$((_attempt + 1))
    done
    printf '%s' "$_output"
    return "$_exit_code"
}

check_connectivity() {
    _target="${1:-https://hianime.at}"
    _timeout="${2:-5}"
    if command -v curl >/dev/null 2>&1; then
        curl -sI --max-time "$_timeout" "$_target" >/dev/null 2>&1
    else
        return 0
    fi
}

resolve_endpoint() {
    printf '%s' "${1:-https://hianime.at}"
}
