#!/bin/sh
# sranime-cli GogoAnime provider plugin
# HTML scraper for GogoAnime / Anitaku mirror

GOGO_BASE="${GOGO_BASE:-https://anitaku.to}"
GOGO_AGENT="${GOGO_AGENT:-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36}"

gogo_curl() {
    curl -sL -A "$GOGO_AGENT" --max-time 10 "$@"
}

gogo_search() {
    _query="$1"
    _encoded_query=$(printf '%s' "$_query" | tr ' ' '+')
    _page=$(gogo_curl "${GOGO_BASE}/search.html?keyword=${_encoded_query}" 2>/dev/null) || return 1
    
    if [ -n "$_page" ]; then
        printf '%s' "$_page" | sed -nE 's|.*<p class="name"><a href="/category/([^"]*)" title="([^"]*)".*|\1\t\2|p'
    else
        return 1
    fi
}

gogo_episodes() {
    _anime_id="$1"
    _page=$(gogo_curl "${GOGO_BASE}/category/${_anime_id}" 2>/dev/null) || return 1
    _movie_id=$(printf '%s' "$_page" | sed -nE 's|.*<input type="hidden" value="([^"]*)" id="movie_id".*|\1|p')
    _default_ep=$(printf '%s' "$_page" | sed -nE 's|.*<input type="hidden" value="([^"]*)" id="default_ep".*|\1|p')
    _alias=$(printf '%s' "$_page" | sed -nE 's|.*<input type="hidden" value="([^"]*)" id="alias_anime".*|\1|p')
    
    if [ -n "$_movie_id" ]; then
        _ep_page=$(gogo_curl "https://ajax.gogocdn.net/ajax/load-list-episode?ep_start=0&ep_end=2000&id=${_movie_id}&default_ep=${_default_ep}&alias=${_alias}" 2>/dev/null)
        printf '%s' "$_ep_page" | sed -nE 's|.*<a href="[^"]*-episode-([0-9.]+)".*<div class="name">.*|\1\t\1|p' | sort -n -k2
    else
        return 1
    fi
}

gogo_m3u8() {
    _ep_no="$1"
    _mode="${2:-sub}"
    refr="${GOGO_BASE}/"
    [ -n "$links" ] && return 0
    return 1
}