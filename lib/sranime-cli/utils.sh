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
    _v1_major="${1%%.*}"
    _v1_rem="${1#*.}"
    _v1_minor="${_v1_rem%%.*}"
    _v1_patch="${_v1_rem#*.}"
    [ "$_v1_patch" = "$_v1_rem" ] && _v1_patch="0"

    _v2_major="${2%%.*}"
    _v2_rem="${2#*.}"
    _v2_minor="${_v2_rem%%.*}"
    _v2_patch="${_v2_rem#*.}"
    [ "$_v2_patch" = "$_v2_rem" ] && _v2_patch="0"

    [ "$_v1_major" -gt "$_v2_major" ] && return 0
    [ "$_v1_major" -lt "$_v2_major" ] && return 1
    [ "$_v1_minor" -gt "$_v2_minor" ] && return 0
    [ "$_v1_minor" -lt "$_v2_minor" ] && return 1
    [ "${_v1_patch:-0}" -ge "${_v2_patch:-0}" ]
}

truncate_str() {
    _str="$1"; _max="${2:-40}"
    _len=${#_str}
    if [ "$_len" -gt "$_max" ]; then
        printf '%s...' "$(printf '%s' "$_str" | cut -c "1-$((_max - 1))")"
    else
        printf '%s' "$_str"
    fi
}
