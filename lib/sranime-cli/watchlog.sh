#!/bin/sh
# sranime-cli watchlog module - lifetime watch history, statistics, and journal

_watchlog_dir="${SRANIME_CLI_HIST_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}"
_watchlog_file="${_watchlog_dir}/watch.log"

_ensure_watchlog() {
    [ ! -d "$_watchlog_dir" ] && mkdir -p "$_watchlog_dir"
    [ ! -f "$_watchlog_file" ] && : >"$_watchlog_file"
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

    while IFS='	' read -r _ts _action _ep _id _title _prov; do
        [ -z "$_title" ] && continue
        if [ -n "$_filter" ]; then
            case "$(printf "%s" "$_title" | tr '[:upper:]' '[:lower:]')" in
                *"$(printf "%s" "$_filter" | tr '[:upper:]' '[:lower:]')"*) ;;
                *) continue ;;
            esac
        fi

        _act_color="\033[1;32m"
        [ "$_action" = "DOWNLOAD" ] && _act_color="\033[1;35m"

        printf "%-19s  ${_act_color}%-8s\033[0m  %-5s  \033[0;33m%-10s\033[0m  %s\n" \
            "$_ts" "$_action" "$_ep" "$_prov" "$_title"
    done <"$_watchlog_file"
}

# Compute and display viewing analytics and summary stats
watchlog_stats() {
    _ensure_watchlog
    if [ ! -s "$_watchlog_file" ]; then
        printf "\033[1;34mNo watch history available for statistics.\033[0m\n"
        return 0
    fi

    _total_watched=$(grep -c '	WATCH	' "$_watchlog_file" 2>/dev/null)
    _total_downloaded=$(grep -c '	DOWNLOAD	' "$_watchlog_file" 2>/dev/null)
    _unique_anime=$(cut -f 5 "$_watchlog_file" | sort -u | grep -c . 2>/dev/null)

    # Estimated watch time (assuming 24 min per episode)
    _total_mins=$(( ${_total_watched:-0} * 24 ))
    _hours=$(( _total_mins / 60 ))
    _mins=$(( _total_mins % 60 ))
    _days=$(( _hours / 24 ))

    _first_date=$(head -n 1 "$_watchlog_file" | cut -f 1)
    _last_date=$(tail -n 1 "$_watchlog_file" | cut -f 1)

    printf "\033[1;36m================ Lifetime Anime Statistics ================\033[0m\n"
    printf "  Episodes Watched   : \033[1;33m%s\033[0m\n" "${_total_watched:-0}"
    printf "  Episodes Downloaded: \033[1;33m%s\033[0m\n" "${_total_downloaded:-0}"
    printf "  Unique Series      : \033[1;33m%s\033[0m\n" "${_unique_anime:-0}"
    if [ "$_days" -gt 0 ]; then
        printf "  Est. Watch Time    : \033[1;33m%d days, %d hrs, %d mins\033[0m (~24 min/ep)\n" "$_days" "$(( _hours % 24 ))" "$_mins"
    else
        printf "  Est. Watch Time    : \033[1;33m%d hrs, %d mins\033[0m (~24 min/ep)\n" "$_hours" "$_mins"
    fi
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