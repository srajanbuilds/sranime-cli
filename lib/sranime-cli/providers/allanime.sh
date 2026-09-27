#!/bin/sh
# sranime-cli AllAnime provider plugin
# API endpoint and scraping logic for AllAnime

ALLANIME_BASE="${ALLANIME_BASE:-https://api.allanime.day}"
ALLANIME_AGENT="${ALLANIME_AGENT:-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36}"

allanime_curl() {
    curl -sL -A "$ALLANIME_AGENT" --max-time 10 "$@"
}

allanime_search() {
    _query="$1"
    _encoded_query=$(printf '%s' "$_query" | tr ' ' '+')
    _resp=$(allanime_curl "${ALLANIME_BASE}/api?variables=%7B%22search%22%3A%7B%22query%22%3A%22${_encoded_query}%22%7D%2C%22limit%22%3A20%2C%22page%22%3A1%7D&extensions=%7B%22persistedQuery%22%3A%7B%22version%22%3A1%2C%22sha256Hash%22%3A%229d7439c90f50ecd9ebd80d7fb1490937d45f5681a72f70eab18fb043878b203a%22%7D%7D" 2>/dev/null)
    
    if [ -n "$_resp" ] && printf '%s' "$_resp" | grep -q '"name"'; then
        printf '%s' "$_resp" | sed 's/{"_id"/\n{"_id"/g' | sed -nE 's/.*"_id":"([^"]+)".*"name":"([^"]+)".*/\1\t\2/p'
    else
        return 1
    fi
}

allanime_episodes() {
    _show_id="$1"
    _resp=$(allanime_curl "${ALLANIME_BASE}/api?variables=%7B%22_id%22%3A%22${_show_id}%22%7D&extensions=%7B%22persistedQuery%22%3A%7B%22version%22%3A1%2C%22sha256Hash%22%3A%22372c3d5e21975e5c709e8631405b018b105a5a14d59f77f9859f518ab57fa4ca%22%7D%7D" 2>/dev/null)
    
    if [ -n "$_resp" ]; then
        printf '%s' "$_resp" | sed 's/"episode"/\n"episode"/g' | sed -nE 's/.*"episodeString":"([^"]+)".*/\1\t\1/p' | sort -n -k2
    else
        return 1
    fi
}

allanime_m3u8() {
    _ep_no="$1"
    _mode="${2:-sub}"
    refr="https://allanime.to/"
    # Fallback structure for resolution
    [ -n "$links" ] && return 0
    return 1
}