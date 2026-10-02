#!/bin/sh
# sranime-cli watchlog module - lifetime watch history, statistics, streaks, and journal

_watchlog_dir="${SRANIME_CLI_HIST_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}"
_watchlog_file="${_watchlog_dir}/watch.log"

_ensure_watchlog() {
    [ ! -d "$_watchlog_dir" ] && mkdir -p "$_watchlog_dir" 2>/dev/null || true
    [ ! -f "$_watchlog_file" ] && : >"$_watchlog_file" 2>/dev/null || true
}

# Convert YYYY-MM-DD to Julian Day Number in pure POSIX arithmetic (no external dependencies)
_date_to_jdn() {
    _d="$1"
    _yr="${_d%%-*}"
    _rest="${_d#*-}"
    _mo="${_rest%%-*}"
    _dy="${_rest#*-}"
    # Strip leading zero for POSIX shell
    _mo="${_mo#0}"
    _dy="${_dy#0}"
    [ -z "$_mo" ] && _mo=0
    [ -z "$_dy" ] && _dy=0

    _a=$(( (14 - _mo) / 12 ))
    _y=$(( _yr + 4800 - _a ))
    _m=$(( _mo + 12 * _a - 3 ))
    _jdn=$(( _dy + (153 * _m + 2) / 5 + 365 * _y + _y / 4 - _y / 100 + _y / 400 - 32045 ))
    printf "%d" "$_jdn"
}

# Append a watch or download event
# Usage: watchlog_append <action> <ep_no> <anime_id> <anime_title> [provider]
watchlog_append() {
    _ensure_watchlog
    _action="${1:-WATCH}"
    _ep="${2:-?}"
    _id="$3"
    _title="$4"
    _prov="${5:-hianime}"
    _ts=$(date "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date)

    [ -z "$_title" ] && return 0
    printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$_ts" "$_action" "$_ep" "$_id" "$_title" "$_prov" >>"$_watchlog_file"
}

# Display formatted watch history
# Usage: watchlog_show [search_filter]
watchlog_show() {
    _ensure_watchlog
    if [ ! -s "$_watchlog_file" ]; then
        printf "\033[1;34mWatch log is empty.\033[0m\n"
        printf "  Entries are recorded automatically when you watch or download episodes.\n"
        return 0
    fi

    _filter="$1"
    printf "\033[1;36m%-19s  %-8s  %-5s  %-10s  %s\033[0m\n" "Date & Time" "Action" "Ep" "Provider" "Anime Title"
    printf "\033[0;90m%s\033[0m\n" "----------------------------------------------------------------------------------"

    _shown=0
    while IFS='	' read -r _ts _action _ep _id _title _prov; do
        [ -z "$_title" ] && continue
        if [ -n "$_filter" ]; then
            _lower_filter=$(printf "%s" "$_filter" | tr '[:upper:]' '[:lower:]')
            _lower_title=$(printf "%s" "$_title" | tr '[:upper:]' '[:lower:]')
            _match=0

            case "$_lower_title" in
                *"$_lower_filter"*) _match=1 ;;
            esac
            case "$_ts" in
                *"$_filter"*) _match=1 ;;
            esac
            case "$_action" in
                "$_filter") _match=1 ;;
            esac
            case "$_prov" in
                "$_filter") _match=1 ;;
            esac

            # Date range matching: YYYY-MM-DD..YYYY-MM-DD
            case "$_filter" in
                *..*)
                    _from="${_filter%%..*}"
                    _to="${_filter##*..}"
                    _date="${_ts%% *}"
                    if [ -n "$_from" ] && [ "$_date" \< "$_from" ]; then
                        _match=0
                    elif [ -n "$_to" ] && [ "$_date" \> "$_to" ]; then
                        _match=0
                    else
                        _match=1
                    fi
                    ;;
            esac

            [ "$_match" -eq 0 ] && continue
        fi

        _act_color="\033[1;32m"
        [ "$_action" = "DOWNLOAD" ] && _act_color="\033[1;35m"

        printf "%-19s  ${_act_color}%-8s\033[0m  %-5s  \033[0;33m%-10s\033[0m  %s\n" \
            "$_ts" "$_action" "$_ep" "$_prov" "$_title"
        _shown=$((_shown + 1))
    done <"$_watchlog_file"

    if [ -n "$_filter" ]; then
        printf "\033[0;90m----------------------------------------------------------------------------------\033[0m\n"
        printf "  Showing %d entries matching: \033[1;33m%s\033[0m\n" "$_shown" "$_filter"
    fi
}

# Compute and display viewing analytics and summary stats
watchlog_stats() {
    _ensure_watchlog
    if [ ! -s "$_watchlog_file" ]; then
        printf "\033[1;34mNo watch history available for statistics.\033[0m\n"
        return 0
    fi

    _total_watched=$(grep -c '	WATCH	' "$_watchlog_file" 2>/dev/null || true)
    _total_downloaded=$(grep -c '	DOWNLOAD	' "$_watchlog_file" 2>/dev/null || true)
    _unique_anime=$(cut -f 5 "$_watchlog_file" | sort -u | grep -c . 2>/dev/null || true)
    _total_watched="${_total_watched:-0}"
    _total_downloaded="${_total_downloaded:-0}"
    _unique_anime="${_unique_anime:-0}" 

    # Estimated watch time (assuming 24 min per episode standard)
    _total_mins=$(( ${_total_watched:-0} * 24 ))
    _hours=$(( _total_mins / 60 ))
    _mins=$(( _total_mins % 60 ))
    _days=$(( _hours / 24 ))

    _first_date=$(head -n 1 "$_watchlog_file" | cut -f 1)
    _last_date=$(tail -n 1 "$_watchlog_file" | cut -f 1)

    # Compute viewing streaks
    _dates=$(cut -f 1 "$_watchlog_file" | cut -d ' ' -f 1 | sort -u)
    _prev_j=0
    _curr_streak=0
    _max_streak=0
    _last_j=0

    for _d in $_dates; do
        _j=$(_date_to_jdn "$_d")
        if [ "$_prev_j" -eq 0 ]; then
            _curr_streak=1
        elif [ $((_j - _prev_j)) -eq 1 ]; then
            _curr_streak=$((_curr_streak + 1))
        else
            _curr_streak=1
        fi
        [ "$_curr_streak" -gt "$_max_streak" ] && _max_streak="$_curr_streak"
        _prev_j="$_j"
        _last_j="$_j"
    done

    # Check if current streak is active (activity on today or yesterday)
    _today_j=$(_date_to_jdn "$(date "+%Y-%m-%d" 2>/dev/null || echo "$_d")")
    if [ $((_today_j - _last_j)) -gt 1 ]; then
        _curr_streak=0
    fi

    printf "\033[1;36m================ Lifetime Anime Statistics ================\033[0m\n"
    printf "  Episodes Watched   : \033[1;33m%s\033[0m\n" "${_total_watched:-0}"
    printf "  Episodes Downloaded: \033[1;33m%s\033[0m\n" "${_total_downloaded:-0}"
    printf "  Unique Series      : \033[1;33m%s\033[0m\n" "${_unique_anime:-0}"
    if [ "$_days" -gt 0 ]; then
        printf "  Est. Watch Time    : \033[1;33m%d days, %d hrs, %d mins\033[0m (~24 min/ep)\n" "$_days" "$(( _hours % 24 ))" "$_mins"
    else
        printf "  Est. Watch Time    : \033[1;33m%d hrs, %d mins\033[0m (~24 min/ep)\n" "$_hours" "$_mins"
    fi
    printf "  Viewing Streaks    : \033[1;32mCurrent: %d days\033[0m | \033[1;35mBest: %d days\033[0m\n" "$_curr_streak" "$_max_streak"
    printf "  First Logged View  : %s\n" "$_first_date"
    printf "  Latest Activity    : %s\n" "$_last_date"
    printf "\033[1;36m----------------- Most Watched Series ---------------------\033[0m\n"

    cut -f 5 "$_watchlog_file" | sort | uniq -c | sort -nr | head -n 5 | while read -r _count _show; do
        [ -n "$_count" ] && printf "  \033[1;32m%3d eps\033[0m - %s\n" "$_count" "$_show"
    done
    printf "\033[1;36m===========================================================\033[0m\n"
}

# Export watch history to JSON or CSV
# Usage: watchlog_export [csv|json]
watchlog_export() {
    _ensure_watchlog
    _format="${1:-json}"

    if [ "$_format" = "csv" ]; then
        printf "timestamp,action,episode,anime_id,anime_title,provider\n"
        while IFS='	' read -r _ts _action _ep _id _title _prov; do
            [ -z "$_title" ] && continue
            _safe_title=$(printf "%s" "$_title" | sed 's/"/""/g')
            printf '"%s","%s","%s","%s","%s","%s"\n' "$_ts" "$_action" "$_ep" "$_id" "$_safe_title" "$_prov"
        done <"$_watchlog_file"
    else
        printf "[\n"
        _first=1
        while IFS='	' read -r _ts _action _ep _id _title _prov; do
            [ -z "$_title" ] && continue
            _safe_title=$(printf "%s" "$_title" | sed 's/"/\\"/g')
            [ "$_first" -eq 0 ] && printf ",\n"
            _first=0
            printf '  {"timestamp": "%s", "action": "%s", "episode": "%s", "anime_id": "%s", "anime_title": "%s", "provider": "%s"}' \
                "$_ts" "$_action" "$_ep" "$_id" "$_safe_title" "$_prov"
        done <"$_watchlog_file"
        printf "\n]\n"
    fi
}

# Clear watch log
watchlog_clear() {
    _ensure_watchlog
    : >"$_watchlog_file"
    printf "\033[1;32mWatch log cleared successfully.\033[0m\n"
}
