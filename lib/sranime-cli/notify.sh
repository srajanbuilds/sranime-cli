#!/bin/sh
# sranime-cli notification module — cross-platform desktop notifications

notify_send() {
    _title="${1:-sranime-cli}"
    _body="${2:-}"
    _icon="${3:-video-x-generic}"

    case "$(uname -s 2>/dev/null)" in
        *Darwin*)
            if command -v osascript >/dev/null 2>&1; then
                osascript -e "display notification \"$_body\" with title \"$_title\"" 2>/dev/null
                return
            fi
            ;;
        *Linux*)
            if command -v notify-send >/dev/null 2>&1; then
                notify-send -i "$_icon" -a "sranime-cli" "$_title" "$_body" 2>/dev/null
                return
            fi
            if command -v termux-notification >/dev/null 2>&1; then
                termux-notification --title "$_title" --content "$_body" 2>/dev/null
                return
            fi
            ;;
    esac
    printf "\033[1;35m[%s]\033[0m %s\n" "$_title" "$_body" >&2
}

notify_episode_start() {
    notify_send "Now Playing" "${1} - Episode ${2}"
}

notify_download_complete() {
    notify_send "Download Complete" "${1} Episode ${2} saved to ${3}"
}
