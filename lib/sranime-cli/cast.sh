#!/bin/sh
# lib/sranime-cli/cast.sh - Smart TV & Chromecast Casting Subsystem
# Turnkey streaming integration with catt (Cast All The Things) and DLNA

cast_is_available() {
    command -v catt >/dev/null 2>&1
}

cast_scan_devices() {
    if ! cast_is_available; then
        printf "\033[1;33m[!] 'catt' is not installed.\033[0m\n"
        printf "Install it via pip: pip install catt\n"
        return 1
    fi
    printf "\033[1;36m==> Scanning local network for Cast devices...\033[0m\n"
    catt scan
}

cast_stream() {
    _url="$1"
    _device="$2"
    _sub_file="${3:-}"
    _title="${4:-sranime-cli Stream}"

    if [ -z "$_url" ]; then
        printf "Error: No streaming URL provided to cast_stream\n" >&2
        return 1
    fi

    if ! cast_is_available; then
        printf "\033[1;31m[!] 'catt' is required for casting.\033[0m\n" >&2
        printf "Install via: pip install catt (or brew install catt / pacman -S catt)\n" >&2
        return 1
    fi

    _catt_args="cast"
    [ -n "$_device" ] && _catt_args="-d \"$_device\" cast"
    [ -n "$_sub_file" ] && [ -f "$_sub_file" ] && _catt_args="$_catt_args -s \"$_sub_file\""

    printf "\033[1;32m==> Casting to %s: %s\033[0m\n" "${_device:-Default Cast Device}" "$_title"
    # Execute in background or foreground
    if [ -n "$_device" ]; then
        catt -d "$_device" cast ${sub_file:+-s "$_sub_file"} "$_url"
    else
        catt cast ${sub_file:+-s "$_sub_file"} "$_url"
    fi
}

cast_control() {
    _action="$1"
    _device="$2"
    if ! cast_is_available; then
        return 1
    fi
    case "$_action" in
        pause|play|stop|rewind|forward|status)
            if [ -n "$_device" ]; then
                catt -d "$_device" "$_action"
            else
                catt "$_action"
            fi
            ;;
        *)
            printf "Usage: cast_control <pause|play|stop|rewind|forward|status> [device]\n" >&2
            return 1
            ;;
    esac
}
