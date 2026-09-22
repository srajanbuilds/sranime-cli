#!/bin/sh
# sranime-cli utility functions — shared helpers used across the codebase

url_encode() {
    printf '%s' "$1" | sed 's/ /+/g'
}

is_positive_int() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

make_temp() {
    _tmp=$(mktemp 2>/dev/null || printf "/tmp/sranime-cli.%s" "$$")
    printf "%s" "$_tmp"
}

semver_ge() {
    _v1_major=$(printf '%s' "$1" | cut -d. -f1)
    _v1_minor=$(printf '%s' "$1" | cut -d. -f2)
    _v1_patch=$(printf '%s' "$1" | cut -d. -f3)
    _v2_major=$(printf '%s' "$2" | cut -d. -f1)
    _v2_minor=$(printf '%s' "$2" | cut -d. -f2)
    _v2_patch=$(printf '%s' "$2" | cut -d. -f3)
    [ "$_v1_major" -gt "$_v2_major" ] && return 0
    [ "$_v1_major" -lt "$_v2_major" ] && return 1
    [ "$_v1_minor" -gt "$_v2_minor" ] && return 0
    [ "$_v1_minor" -lt "$_v2_minor" ] && return 1
    [ "${_v1_patch:-0}" -ge "${_v2_patch:-0}" ]
}

truncate_str() {
    _str="$1"; _max="${2:-40}"
    _len=$(printf '%s' "$_str" | wc -c | tr -d '[:space:]')
    if [ "$_len" -gt "$_max" ]; then
        printf '%s' "$_str" | cut -c "1-$((_max - 1))"
        printf '...'
    else
        printf '%s' "$_str"
    fi
}
