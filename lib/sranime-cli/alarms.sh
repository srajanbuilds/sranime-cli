#!/bin/sh
# sranime-cli Simulcast Airing Alarms & Episode Alerts module
# Cross-references user watch history & AniList against live broadcast schedules.
#
# Provides:
#   - alarms_get_watchlist_titles
#   - alarms_fetch_schedule [hours]
#   - alarms_check_upcoming [hours]
#   - alarms_notify [hours]
#   - alarms_calendar_mine [hours]

_alarms_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

# Extract unique anime titles from local watch history and tracking cache
alarms_get_watchlist_titles() {
    _watch_file="${SRANIME_CLI_HIST_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}/watch.log"
    _hist_file="${SRANIME_CLI_HIST_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}/sranime-hsts"

    _titles=""
    if [ -f "$_watch_file" ]; then
        _titles=$(cut -f2 "$_watch_file" 2>/dev/null | sort -u | grep -v '^[[:space:]]*$' || true)
    fi
    if [ -f "$_hist_file" ]; then
        _h_titles=$(cut -f2 "$_hist_file" 2>/dev/null | sort -u | grep -v '^[[:space:]]*$' || true)
        _titles=$(printf "%s
%s" "$_titles" "$_h_titles" | sort -u | grep -v '^[[:space:]]*$' || true)
    fi

    printf "%s
" "$_titles"
}

# Fetch upcoming airing schedule from AniList GraphQL for a given window (in hours)
# Emits TSV: media_id 	 title 	 episode 	 time_until_seconds 	 formatted_time 	 poster_url
alarms_fetch_schedule() {
    _window_hours="${1:-24}"
    _window_sec=$(( _window_hours * 3600 ))

    _now=$(date +%s 2>/dev/null || python -c "import time; print(int(time.time()))")
    _future=$(( _now + _window_sec ))

    _query=$(cat << GRAPHQLEOF
{"query": "query { Page(page: 1, perPage: 50) { airingSchedules(airingAt_greater: ${_now}, airingAt_lesser: ${_future}, sort: TIME) { id airingAt timeUntilAiring episode media { id title { english romaji } coverImage { medium } } } } }"}
GRAPHQLEOF
)

    _resp=$(curl -sL --max-time 10 -X POST         -H "Content-Type: application/json"         -H "Accept: application/json"         -H "User-Agent: $_alarms_agent"         -d "$_query"         "https://graphql.anilist.co" 2>/dev/null)

    [ -z "$_resp" ] && return 1

    if command -v python >/dev/null 2>&1; then
        printf '%s' "$_resp" | python -c '
import sys, json
try:
    data = json.load(sys.stdin)
    schedules = data.get("data", {}).get("Page", {}).get("airingSchedules", [])
    for s in schedules:
        m = s.get("media") or {}
        t = m.get("title", {}).get("english") or m.get("title", {}).get("romaji") or "Unknown"
        ep = s.get("episode") or "?"
        sec = s.get("timeUntilAiring") or 0
        img = m.get("coverImage", {}).get("medium") or ""
        
        # Format countdown
        mins = sec // 60
        if mins < 60:
            formatted = f"{mins}m"
        elif mins < 1440:
            formatted = f"{mins // 60}h {mins % 60:02d}m"
        else:
            formatted = f"{mins // 1440}d {(mins % 1440) // 60}h"
            
        print(f"{m.get("id")}	{t}	{ep}	{sec}	{formatted}	{img}")
except Exception:
    sys.exit(1)
' 2>/dev/null
    fi
}

# Cross-reference upcoming schedule with user watchlist
# Returns matched upcoming rows
alarms_check_upcoming() {
    _window_hours="${1:-24}"
    _watchlist=$(alarms_get_watchlist_titles)
    [ -z "$_watchlist" ] && return 0

    _sched=$(alarms_fetch_schedule "$_window_hours")
    [ -z "$_sched" ] && return 0

    if command -v python >/dev/null 2>&1; then
        python -c '
import sys

watch_raw = sys.argv[1]
sched_raw = sys.argv[2]

watched = [w.strip().lower() for w in watch_raw.splitlines() if w.strip()]
for line in sched_raw.splitlines():
    parts = line.split("	")
    if len(parts) >= 3:
        title = parts[1].strip()
        t_lower = title.lower()
        # Check if watched series matches upcoming schedule
        for w in watched:
            if w in t_lower or t_lower in w:
                print(line)
                break
' "$_watchlist" "$_sched" 2>/dev/null
    fi
}

# Send desktop notifications for airing episodes within the window
alarms_notify() {
    _window_hours="${1:-2}"
    _matches=$(alarms_check_upcoming "$_window_hours")
    [ -z "$_matches" ] && return 0

    _count=0
    printf "%s
" "$_matches" | while IFS= read -r _row || [ -n "$_row" ]; do
        [ -z "$_row" ] && continue
        _title=$(printf "%s" "$_row" | cut -f2)
        _ep=$(printf "%s" "$_row" | cut -f3)
        _time=$(printf "%s" "$_row" | cut -f5)
        _img=$(printf "%s" "$_row" | cut -f6)

        if [ "${SRANIME_CLI_PLAYER:-$player}" = "debug" ]; then
            printf "DEBUG_ALARM_NOTIFY: title=%s ep=%s time=%s
" "$_title" "$_ep" "$_time"
        else
            if command -v notify-send >/dev/null 2>&1; then
                notify-send -i "video-television" "Anime Airing Alert" "${_title} Episode ${_ep} airs in ${_time}!"
            elif command -v osascript >/dev/null 2>&1; then
                osascript -e "display notification "${_title} Episode ${_ep} airs in ${_time}!" with title "Anime Airing Alert""
            elif command -v powershell.exe >/dev/null 2>&1; then
                powershell.exe -Command "[reflection.assembly]::loadwithpartialname('System.Windows.Forms'); [System.Windows.Forms.MessageBox]::Show('${_title} Episode ${_ep} airs in ${_time}!', 'Anime Airing Alert')" >/dev/null 2>&1 || true
            fi
        fi
        _count=$(( _count + 1 ))
    done
}

# Display a customized airing calendar containing only user's anime
alarms_calendar_mine() {
    _window_hours="${1:-48}"
    printf "====================================================
"
    printf "  My Simulcast Airing Radar (Next %dh)
" "$_window_hours"
    printf "====================================================
"

    _matches=$(alarms_check_upcoming "$_window_hours")
    if [ -z "$_matches" ]; then
        printf "No shows from your watchlist airing in the next %d hours.
" "$_window_hours"
        return 0
    fi

    printf "%-32s  %-8s  %-10s
" "Anime Title" "Episode" "Airing In"
    printf -- "----------------------------------------------------
"
    printf "%s
" "$_matches" | while IFS= read -r _row || [ -n "$_row" ]; do
        [ -z "$_row" ] && continue
        _title=$(printf "%s" "$_row" | cut -f2)
        _ep=$(printf "%s" "$_row" | cut -f3)
        _time=$(printf "%s" "$_row" | cut -f5)
        printf "%-32.32s  Ep %-5s  in %-10s
" "$_title" "$_ep" "$_time"
    done
    printf "====================================================
"
}
