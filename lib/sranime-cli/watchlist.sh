#!/bin/sh
# sranime-cli watchlist module — manage a persistent favorites list

_watchlist_dir="${SRANIME_CLI_HIST_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}"
_watchlist_file="${_watchlist_dir}/watchlist"

_ensure_watchlist() {
    [ ! -d "$_watchlist_dir" ] && mkdir -p "$_watchlist_dir"
    [ ! -f "$_watchlist_file" ] && : >"$_watchlist_file"
}

watchlist_add() {
    _ensure_watchlist
    _id="$1"; _title="$2"
    if grep -q "	${_id}	" "$_watchlist_file" 2>/dev/null; then
        printf "\033[1;33mAlready in watchlist:\033[0m %s\n" "$_title"
        return 0
    fi
    _timestamp=$(date +%s 2>/dev/null || printf "0")
    printf "%s\t%s\t%s\n" "$_timestamp" "$_id" "$_title" >>"$_watchlist_file"
    printf "\033[1;32m+ Added to watchlist:\033[0m %s\n" "$_title"
}

watchlist_remove() {
    _ensure_watchlist
    _id="$1"
    if grep -q "	${_id}	" "$_watchlist_file" 2>/dev/null; then
        grep -v "	${_id}	" "$_watchlist_file" >"${_watchlist_file}.new"
        mv "${_watchlist_file}.new" "$_watchlist_file"
        printf "\033[1;32m- Removed from watchlist\033[0m\n"
    else
        printf "\033[1;33mNot found in watchlist\033[0m\n"
    fi
}

watchlist_show() {
    _ensure_watchlist
    if [ ! -s "$_watchlist_file" ]; then
        printf "\033[1;34mWatchlist is empty.\033[0m\n"
        printf "  Add anime with: sranime-cli --watchlist-add <query>\n"
        return 0
    fi
    printf "\033[1;36m--- Watchlist ---\033[0m\n"
    _n=1
    while IFS='	' read -r _ts _id _title; do
        [ -z "$_id" ] && continue
        printf "  \033[1;33m%2d.\033[0m %s\n" "$_n" "$_title"
        _n=$((_n + 1))
    done <"$_watchlist_file"
}

watchlist_clear() {
    _ensure_watchlist
    : >"$_watchlist_file"
    printf "\033[1;32mWatchlist cleared.\033[0m\n"
}
