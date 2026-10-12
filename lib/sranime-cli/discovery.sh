#!/bin/sh
# sranime-cli discovery module — seasonal browser, airing calendar, and recommendations
#
# Provides:
#   - discovery_current_season
#   - discovery_format_countdown <seconds>
#   - discovery_fetch_seasonal [season] [year]
#   - discovery_fetch_trending
#   - discovery_fetch_calendar [hours]
#   - discovery_fetch_similar <anime_title>

_disc_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
_disc_cache_dir="${SRANIME_CLI_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/sranime-cli}/discovery_cache"

_ensure_disc_cache() {
    [ ! -d "$_disc_cache_dir" ] && mkdir -p "$_disc_cache_dir" 2>/dev/null || true
}

# Determine current anime broadcast season and year
# Returns: <SEASON> <YEAR> (e.g. "FALL 2026")
discovery_current_season() {
    _month=$(date +"%m" 2>/dev/null || echo "01")
    _month=$(printf "%s" "$_month" | sed 's/^0//')
    _year=$(date +"%Y" 2>/dev/null || echo "2026")

    case "$_month" in
        1|2|3)    _season="WINTER" ;;
        4|5|6)    _season="SPRING" ;;
        7|8|9)    _season="SUMMER" ;;
        10|11|12) _season="FALL" ;;
        *)        _season="FALL" ;;
    esac

    printf "%s %s" "$_season" "$_year"
}

# Format seconds until airing into human-friendly string (e.g. "2h 15m", "4d 6h")
discovery_format_countdown() {
    _sec="${1:-0}"
    _sec=$(printf "%s" "$_sec" | grep -o '^[0-9]\+' || echo 0)
    [ -z "$_sec" ] && _sec=0

    if [ "$_sec" -le 0 ]; then
        printf "Aired"
        return 0
    fi

    _mins=$(( _sec / 60 ))
    if [ "$_mins" -lt 60 ]; then
        printf "%dm" "$_mins"
        return 0
    fi

    _hrs=$(( _mins / 60 ))
    _rem_mins=$(( _mins % 60 ))
    if [ "$_hrs" -lt 24 ]; then
        printf "%dh %02dm" "$_hrs" "$_rem_mins"
        return 0
    fi

    _days=$(( _hrs / 24 ))
    _rem_hrs=$(( _hrs % 24 ))
    printf "%dd %dh" "$_days" "$_rem_hrs"
}

# Query AniList GraphQL API with JSON payload
# Usage: _discovery_query <json_body>
_discovery_query() {
    _body="$1"
    curl -sL --max-time 10 -X POST         -H "Content-Type: application/json"         -H "Accept: application/json"         -H "User-Agent: $_disc_agent"         -d "$_body"         "https://graphql.anilist.co" 2>/dev/null
}

# Fetch popular anime for a season and emit rows for menu/fzf:
# Schema: <index> 	 <search_query> 	 <display_label>
discovery_fetch_seasonal() {
    _season="$1"
    _year="$2"

    if [ -z "$_season" ] || [ -z "$_year" ]; then
        _curr=$(discovery_current_season)
        _season="${_season:-$(printf "%s" "$_curr" | cut -d' ' -f1)}"
        _year="${_year:-$(printf "%s" "$_curr" | cut -d' ' -f2)}"
    fi
    _season=$(printf "%s" "$_season" | tr '[:lower:]' '[:upper:]')

    _query=$(cat << GRAPHQLEOF
{"query": "query { Page(page: 1, perPage: 30) { media(season: ${_season}, seasonYear: ${_year}, type: ANIME, sort: POPULARITY_DESC) { id title { english romaji } episodes averageScore format } } }"}
GRAPHQLEOF
)

    _resp=$(_discovery_query "$_query")
    [ -z "$_resp" ] && return 1

    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$_resp" | jq -r '
            .data.Page.media // [] | to_entries[] |
            "\(.key + 1)	\(.value.title.english // .value.title.romaji)	\(.value.title.english // .value.title.romaji) [★ \(.value.averageScore // "?")%] (\(.value.format // "TV") • \(.value.episodes // "?") eps)"
        ' 2>/dev/null
    elif command -v python >/dev/null 2>&1; then
        printf '%s' "$_resp" | python -c '
import sys, json
try:
    data = json.load(sys.stdin)
    items = data.get("data", {}).get("Page", {}).get("media", [])
    for idx, m in enumerate(items, 1):
        t = m["title"]["english"] or m["title"]["romaji"]
        score = m.get("averageScore") or "?"
        fmt = m.get("format") or "TV"
        eps = m.get("episodes") or "?"
        print(f"{idx}	{t}	{t} [★ {score}%] ({fmt} • {eps} eps)")
except Exception:
    sys.exit(1)
' 2>/dev/null
    fi
}

# Fetch trending anime right now and emit rows for menu/fzf
discovery_fetch_trending() {
    _query=$(cat << GRAPHQLEOF
{"query": "query { Page(page: 1, perPage: 25) { media(type: ANIME, sort: TRENDING_DESC) { id title { english romaji } episodes averageScore format } } }"}
GRAPHQLEOF
)

    _resp=$(_discovery_query "$_query")
    [ -z "$_resp" ] && return 1

    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$_resp" | jq -r '
            .data.Page.media // [] | to_entries[] |
            "\(.key + 1)	\(.value.title.english // .value.title.romaji)	\(.value.title.english // .value.title.romaji) [★ \(.value.averageScore // "?")%] (\(.value.format // "TV") • \(.value.episodes // "?") eps)"
        ' 2>/dev/null
    elif command -v python >/dev/null 2>&1; then
        printf '%s' "$_resp" | python -c '
import sys, json
try:
    data = json.load(sys.stdin)
    items = data.get("data", {}).get("Page", {}).get("media", [])
    for idx, m in enumerate(items, 1):
        t = m["title"]["english"] or m["title"]["romaji"]
        score = m.get("averageScore") or "?"
        fmt = m.get("format") or "TV"
        eps = m.get("episodes") or "?"
        print(f"{idx}	{t}	{t} [★ {score}%] ({fmt} • {eps} eps)")
except Exception:
    sys.exit(1)
' 2>/dev/null
    fi
}

# Fetch upcoming airing schedule table
# Usage: discovery_fetch_calendar [hours_ahead]
discovery_fetch_calendar() {
    _hours="${1:-48}"
    _now=$(date +"%s" 2>/dev/null || echo 0)
    _sec_ahead=$(( _hours * 3600 ))
    _end=$(( _now + _sec_ahead ))

    _query=$(cat << GRAPHQLEOF
{"query": "query (\$start: Int, \$end: Int) { Page(page: 1, perPage: 35) { airingSchedules(airingAt_greater: \$start, airingAt_lesser: \$end, sort: TIME) { id episode airingAt timeUntilAiring media { title { english romaji } format } } } }", "variables": {"start": $_now, "end": $_end}}
GRAPHQLEOF
)

    _resp=$(_discovery_query "$_query")
    [ -z "$_resp" ] && return 1

    printf "[1;36m==================== Upcoming Airing Schedule ====================[0m

"
    printf "  [1m%-14s %-8s %-42s[0m
" "Countdown" "Episode" "Anime Title"
    printf "  %-14s %-8s %-42s
" "--------------" "-------" "------------------------------------------"

    if command -v python >/dev/null 2>&1; then
        printf '%s' "$_resp" | python -c '
import sys, json
try:
    data = json.load(sys.stdin)
    items = data.get("data", {}).get("Page", {}).get("airingSchedules", [])
    for s in items:
        m = s.get("media", {})
        title = m.get("title", {}).get("english") or m.get("title", {}).get("romaji") or "Unknown"
        ep = s.get("episode", 1)
        sec = s.get("timeUntilAiring", 0)
        mins = sec // 60
        if mins < 60:
            cd = f"In {mins}m"
        elif mins < 1440:
            hrs = mins // 60
            rm = mins % 60
            cd = f"In {hrs}h {rm:02d}m"
        else:
            days = mins // 1440
            hrs = (mins % 1440) // 60
            cd = f"In {days}d {hrs}h"
        
        # Color formatted ANSI line
        print(f"  [1;33m{cd:<14}[0m [1;34mEp {ep:<5}[0m [1;37m{title[:42]:<42}[0m")
except Exception:
    sys.exit(1)
' 2>/dev/null
    else
        printf "Airing schedule retrieved.
"
    fi
    printf "
[0;90mRun 'sranime-cli "<title>"' to search and stream past episodes.[0m
"
}

# Fetch top recommendations for a given anime title and emit rows for menu/fzf
discovery_fetch_similar() {
    _title="$1"
    [ -z "$_title" ] && return 1

    _safe_title=$(printf '%s' "$_title" | sed 's/"/\"/g')
    _query=$(cat << GRAPHQLEOF
{"query": "query (\$search: String) { Media(search: \$search, type: ANIME) { id title { english romaji } recommendations(sort: RATING_DESC, perPage: 8) { nodes { mediaRecommendation { id title { english romaji } format averageScore } rating } } } }", "variables": {"search": "$_safe_title"}}
GRAPHQLEOF
)

    _resp=$(_discovery_query "$_query")
    [ -z "$_resp" ] && return 1

    if command -v python >/dev/null 2>&1; then
        printf '%s' "$_resp" | python -c '
import sys, json
try:
    data = json.load(sys.stdin)
    recs = data.get("data", {}).get("Media", {}).get("recommendations", {}).get("nodes", [])
    idx = 1
    for r in recs:
        mr = r.get("mediaRecommendation")
        if not mr:
            continue
        title = mr.get("title", {}).get("english") or mr.get("title", {}).get("romaji")
        score = mr.get("averageScore") or "?"
        votes = r.get("rating") or 0
        fmt = mr.get("format") or "TV"
        print(f"{idx}	{title}	{title} [★ {score}%] ({fmt} • {votes} community votes)")
        idx += 1
except Exception:
    sys.exit(1)
' 2>/dev/null
    elif command -v jq >/dev/null 2>&1; then
        printf '%s' "$_resp" | jq -r '
            [.data.Media.recommendations.nodes[].mediaRecommendation | select(. != null)] | to_entries[] |
            "\(.key + 1)	\(.value.title.english // .value.title.romaji)	\(.value.title.english // .value.title.romaji) [★ \(.value.averageScore // "?")%]"
        ' 2>/dev/null
    fi
}
