#!/bin/sh
# sranime-cli Manga Companion & Reader Engine
# Powered by MangaDex REST API & Local CBZ Downloader
#
# Provides:
#   - manga_search <query>
#   - manga_parse_search <json>
#   - manga_list_chapters <manga_id> [lang]
#   - manga_fetch_pages <chapter_id>
#   - manga_read_chapter <chapter_id> <title> <chapter_num>
#   - manga_download_chapter <chapter_id> <title> <chapter_num> [out_dir]
#   - manga_save_checkpoint <title> <chapter_num> <page_num>
#   - manga_get_checkpoint <title>
#   - manga_interactive [query]

_manga_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
_manga_cache_dir="${SRANIME_CLI_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/sranime-cli}/manga"
_manga_state_dir="${SRANIME_CLI_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}"
_manga_cp_file="${_manga_state_dir}/manga_checkpoints.tsv"

_ensure_manga_dirs() {
    [ ! -d "$_manga_cache_dir" ] && mkdir -p "$_manga_cache_dir" 2>/dev/null || true
    [ ! -d "$_manga_state_dir" ] && mkdir -p "$_manga_state_dir" 2>/dev/null || true
    [ ! -f "$_manga_cp_file" ] && : > "$_manga_cp_file" 2>/dev/null || true
}

# Search MangaDex API
manga_search() {
    _query="$1"
    [ -z "$_query" ] && return 1

    _encoded=$(printf '%s' "$_query" | tr ' ' '+')
    _url="https://api.mangadex.org/manga?title=${_encoded}&limit=15&includes[]=cover_art"

    curl -sL --max-time 10 -H "User-Agent: $_manga_agent" "$_url" 2>/dev/null
}

# Parse search result JSON
# Emits: <index>	<id>	<title> (<year>) [<status>]
manga_parse_search() {
    _json="$1"
    [ -z "$_json" ] && return 1

    if command -v python >/dev/null 2>&1; then
        printf '%s' "$_json" | python -c '
import sys, json
try:
    data = json.load(sys.stdin)
    items = data.get("data", [])
    for idx, m in enumerate(items, 1):
        mid = m.get("id") or ""
        attrs = m.get("attributes", {})
        title_dict = attrs.get("title", {})
        title = title_dict.get("en") or next(iter(title_dict.values()), "Unknown Manga")
        year = attrs.get("year") or "?"
        status = (attrs.get("status") or "Ongoing").capitalize()
        print(f"{idx}	{mid}	{title} ({year}) [{status}]")
except Exception:
    sys.exit(1)
' 2>/dev/null
    fi
}

# List chapters for a manga series
# Emits: <index>	<chapter_id>	Chapter <num>: <title> (<pages> pages)
manga_list_chapters() {
    _manga_id="$1"
    _lang="${2:-en}"

    [ -z "$_manga_id" ] && return 1
    _url="https://api.mangadex.org/manga/${_manga_id}/feed?translatedLanguage[]=${_lang}&order[chapter]=asc&limit=100"

    _resp=$(curl -sL --max-time 10 -H "User-Agent: $_manga_agent" "$_url" 2>/dev/null)
    [ -z "$_resp" ] && return 1

    if command -v python >/dev/null 2>&1; then
        printf '%s' "$_resp" | python -c '
import sys, json
try:
    data = json.load(sys.stdin)
    chapters = data.get("data", [])
    for idx, c in enumerate(chapters, 1):
        cid = c.get("id") or ""
        attrs = c.get("attributes", {})
        ch_num = attrs.get("chapter") or str(idx)
        ch_title = attrs.get("title") or ""
        pages = attrs.get("pages") or "?"
        title_str = f" - {ch_title}" if ch_title else ""
        print(f"{idx}	{cid}	Chapter {ch_num}{title_str} ({pages} pages)	{ch_num}")
except Exception:
    sys.exit(1)
' 2>/dev/null
    fi
}

# Fetch page URLs for chapter from MangaDex @ Home
manga_fetch_pages() {
    _chapter_id="$1"
    [ -z "$_chapter_id" ] && return 1

    _url="https://api.mangadex.org/at-home/server/${_chapter_id}"
    _resp=$(curl -sL --max-time 10 -H "User-Agent: $_manga_agent" "$_url" 2>/dev/null)
    [ -z "$_resp" ] && return 1

    if command -v python >/dev/null 2>&1; then
        printf '%s' "$_resp" | python -c '
import sys, json
try:
    data = json.load(sys.stdin)
    base_url = data.get("baseUrl", "")
    ch_data = data.get("chapter", {})
    ch_hash = ch_data.get("hash", "")
    pages = ch_data.get("data", [])
    for idx, p in enumerate(pages, 1):
        full_url = f"{base_url}/data/{ch_hash}/{p}"
        print(f"{idx}	{full_url}")
except Exception:
    sys.exit(1)
' 2>/dev/null
    fi
}

# Checkpoint management
manga_save_checkpoint() {
    _title="$1"
    _chapter="$2"
    _page="${3:-1}"

    [ -z "$_title" ] || [ -z "$_chapter" ] && return 1
    _ensure_manga_dirs

    _tmp="${_manga_cp_file}.tmp.$$"
    if [ -f "$_manga_cp_file" ]; then
        grep -v "^${_title}	" "$_manga_cp_file" > "$_tmp" 2>/dev/null || true
    else
        : > "$_tmp"
    fi

    _now=$(date +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "2026-09-28T00:00:00Z")
    printf "%s	%s	%s	%s
" "$_title" "$_chapter" "$_page" "$_now" >> "$_tmp"
    mv -f "$_tmp" "$_manga_cp_file" 2>/dev/null || cp -f "$_tmp" "$_manga_cp_file" 2>/dev/null || true
    rm -f "$_tmp" 2>/dev/null || true
}

manga_get_checkpoint() {
    _title="$1"
    [ -z "$_title" ] && return 1
    [ ! -f "$_manga_cp_file" ] && return 1

    grep "^${_title}	" "$_manga_cp_file" 2>/dev/null | tail -n 1
}

# Read chapter interactively
manga_read_chapter() {
    _chapter_id="$1"
    _title="${2:-Manga}"
    _ch_num="${3:-1}"

    [ -z "$_chapter_id" ] && return 1

    if [ "${SRANIME_CLI_PLAYER:-$player}" = "debug" ]; then
        printf "DEBUG_MANGA_READ: id=%s title=%s chapter=%s
" "$_chapter_id" "$_title" "$_ch_num"
        return 0
    fi

    _ensure_manga_dirs
    _ch_dir="$_manga_cache_dir/$_chapter_id"
    mkdir -p "$_ch_dir" 2>/dev/null || true

    printf "Fetching chapter pages...
"
    _pages_tsv=$(manga_fetch_pages "$_chapter_id")
    [ -z "$_pages_tsv" ] && { printf "Failed to load pages for chapter %s.
" "$_ch_num"; return 1; }

    # Save initial checkpoint
    manga_save_checkpoint "$_title" "$_ch_num" "1"

    # Reading loop
    _page_num=1
    _total_pages=$(printf "%s
" "$_pages_tsv" | wc -l | tr -d "[:space:]")

    while [ "$_page_num" -le "$_total_pages" ]; do
        _page_url=$(printf "%s
" "$_pages_tsv" | sed -n "${_page_num}p" | cut -f2)
        _page_file="$_ch_dir/page_${_page_num}.jpg"

        if [ ! -s "$_page_file" ]; then
            curl -sL --max-time 10 "$_page_url" -o "$_page_file" 2>/dev/null || true
        fi

        tput clear 2>/dev/null || true
        printf "== %s - Chapter %s (Page %d/%d) ==
" "$_title" "$_ch_num" "$_page_num" "$_total_pages"

        if command -v chafa >/dev/null 2>&1 && [ -s "$_page_file" ]; then
            chafa -s 60x32 "$_page_file" 2>/dev/null || true
        else
            printf "[Page %d rendered: %s]
" "$_page_num" "$_page_file"
        fi

        manga_save_checkpoint "$_title" "$_ch_num" "$_page_num"

        printf "
[N/Space] Next  •  [P] Prev  •  [Q] Quit: "
        read -r _action
        case "$_action" in
            p|P)
                [ "$_page_num" -gt 1 ] && _page_num=$((_page_num - 1))
                ;;
            q|Q)
                break
                ;;
            *)
                _page_num=$((_page_num + 1))
                ;;
        esac
    done

    printf "
Saved reading bookmark at Chapter %s (Page %d).
" "$_ch_num" "$_page_num"
}

# Download chapter pages into CBZ / image folder
manga_download_chapter() {
    _chapter_id="$1"
    _title="${2:-Manga}"
    _ch_num="${3:-1}"
    _out_dir="${4:-$HOME/Downloads/Manga}"

    [ -z "$_chapter_id" ] && return 1

    if [ "${SRANIME_CLI_PLAYER:-$player}" = "debug" ]; then
        printf "DEBUG_MANGA_DOWNLOAD: id=%s title=%s chapter=%s
" "$_chapter_id" "$_title" "$_ch_num"
        return 0
    fi

    mkdir -p "$_out_dir" 2>/dev/null || true
    printf "Downloading %s Chapter %s...
" "$_title" "$_ch_num"
    _pages_tsv=$(manga_fetch_pages "$_chapter_id")
    [ -z "$_pages_tsv" ] && return 1

    _target_folder="$_out_dir/${_title} - Ch ${_ch_num}"
    mkdir -p "$_target_folder" 2>/dev/null || true

    printf "%s
" "$_pages_tsv" | while IFS="	" read -r _pnum _purl; do
        [ -z "$_purl" ] && continue
        _pfile=$(printf "%s/%03d.jpg" "$_target_folder" "$_pnum")
        curl -sL --max-time 10 "$_purl" -o "$_pfile" 2>/dev/null || true
    done

    printf "Downloaded Chapter %s to: %s
" "$_ch_num" "$_target_folder"
}

# Interactive Manga Hub
manga_interactive() {
    _query="$1"
    if [ -z "$_query" ]; then
        printf "Enter manga title to search: "
        read -r _query
    fi
    [ -z "$_query" ] && return 1

    printf "Searching MangaDex for '%s'...
" "$_query"
    _json=$(manga_search "$_query")
    [ -z "$_json" ] && { printf "No manga found for '%s'.
" "$_query"; return 1; }

    _manga_list=$(manga_parse_search "$_json")
    [ -z "$_manga_list" ] && { printf "No matching manga series found.
"; return 1; }

    _selected_manga=$(printf "%s
" "$_manga_list" | menu "Select Manga Series: ")
    [ -z "$_selected_manga" ] && return 0

    _manga_id=$(printf "%s" "$_selected_manga" | cut -f2)
    _manga_title=$(printf "%s" "$_selected_manga" | cut -f3)

    printf "Fetching chapters for %s...
" "$_manga_title"
    _chapters=$(manga_list_chapters "$_manga_id" "${manga_lang:-en}")
    [ -z "$_chapters" ] && { printf "No chapters found for this manga.
"; return 1; }

    _selected_ch=$(printf "%s
" "$_chapters" | menu "Select Chapter: ")
    [ -z "$_selected_ch" ] && return 0

    _chapter_id=$(printf "%s" "$_selected_ch" | cut -f2)
    _ch_num=$(printf "%s" "$_selected_ch" | cut -f4)

    manga_read_chapter "$_chapter_id" "$_manga_title" "$_ch_num"
}
