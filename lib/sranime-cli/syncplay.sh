#!/bin/sh
# sranime-cli syncplay module — turnkey synchronized watch parties
#
# Provides:
#   - syncplay_format_args <room_name> <player_bin> [extra_flags]
#   - syncplay_launch <video_url> <room_name> [title] [sub_url]

# Format command line arguments for Syncplay client
syncplay_format_args() {
    _room="${1:-WatchParty}"
    _player="${2:-mpv}"
    _title="$3"

    printf -- "--no-gui --room %s --player-path %s" "$_room" "$_player"
}

# Resolve and launch Syncplay client
syncplay_launch() {
    _url="$1"
    _room="${2:-WatchParty}"
    _title="${3:-Anime}"
    _sub="$4"

    [ -z "$_url" ] && return 1

    _syncplay_bin=""
    case "$(uname -s 2>/dev/null)" in
        *Darwin*)
            if [ -x "/Applications/Syncplay.app/Contents/MacOS/syncplay" ]; then
                _syncplay_bin="/Applications/Syncplay.app/Contents/MacOS/syncplay"
            fi
            ;;
        *MINGW* | *MSYS*)
            if command -v syncplay.exe >/dev/null 2>&1; then
                _syncplay_bin="syncplay.exe"
            elif [ -x "/c/Program Files (x86)/Syncplay/Syncplay.exe" ]; then
                _syncplay_bin="/c/Program Files (x86)/Syncplay/Syncplay.exe"
            fi
            ;;
        *)
            if command -v syncplay >/dev/null 2>&1; then
                _syncplay_bin="syncplay"
            fi
            ;;
    esac

    if [ -z "$_syncplay_bin" ] && command -v syncplay >/dev/null 2>&1; then
        _syncplay_bin="syncplay"
    fi

    if [ -z "$_syncplay_bin" ]; then
        printf "\033[1;31mSyncplay is not installed.\033[0m\n" >&2
        printf "Install it from: \033[1;34mhttps://syncplay.pl/download/\033[0m\n" >&2
        return 1
    fi

    printf "\033[1;36m==> Launching Syncplay Room:\033[0m %s\n" "$_room"
    printf "  Anime : %s\n" "$_title"
    printf "  Host  : syncplay.pl:8999\n"

    "$_syncplay_bin" --no-gui --room "$_room" "$_url"
}
