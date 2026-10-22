#!/bin/sh
# sranime-cli AnimeThemes.moe Theme Song & OST Jukebox module
#
# Provides:
#   - themes_search <query>
#   - themes_parse_anime_list <json>
#   - themes_extract_tracks <json> [type_filter] [target_slug]
#   - themes_play_track <video_url> <title> <is_audio_only>
#   - themes_download_track <video_url> <output_filename>
#   - themes_interactive <query> [type_filter] [is_audio_only] [download_mode]

_themes_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
_themes_cache_dir="${SRANIME_CLI_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/sranime-cli}/themes"

_ensure_themes_cache() {
    [ ! -d "$_themes_cache_dir" ] && mkdir -p "$_themes_cache_dir" 2>/dev/null || true
}

# Search AnimeThemes API for an anime title
themes_search() {
    _query="$1"
    [ -z "$_query" ] && return 1

    _encoded=$(printf '%s' "$_query" | tr ' ' '+')
    _url="https://api.animethemes.moe/anime?q=${_encoded}&include=animethemes.animethemeentries.videos,animethemes.song.artists"

    curl -sL --max-time 10 -H "User-Agent: $_themes_agent" "$_url" 2>/dev/null
}

themes_parse_anime_list() {
    _json="$1"
    [ -z "$_json" ] && return 1

    if command -v python >/dev/null 2>&1; then
        printf '%s' "$_json" | python -c '
import sys, json
try:
    data = json.load(sys.stdin)
    animes = data.get("anime", [])
    for idx, a in enumerate(animes, 1):
        name = a.get("name") or "Unknown"
        year = a.get("year") or "?"
        slug = a.get("slug") or ""
        themes = len(a.get("animethemes", []))
        print(f"{idx}	{slug}	{name} ({year}) [{themes} themes]")
except Exception:
    sys.exit(1)
' 2>/dev/null
    elif command -v jq >/dev/null 2>&1; then
        printf '%s' "$_json" | jq -r '
            .anime // [] | to_entries[] |
            "\(.key + 1)	\(.value.slug)	\(.value.name) (\(.value.year // "?")) [\(.value.animethemes | length) themes]"
        ' 2>/dev/null
    fi
}

themes_extract_tracks() {
    _json="$1"
    _type_filter=$(printf "%s" "${2:-all}" | tr '[:upper:]' '[:lower:]')
    _target_slug="$3"

    [ -z "$_json" ] && return 1

    if command -v python >/dev/null 2>&1; then
        printf '%s' "$_json" | python -c '
import sys, json
filter_type = sys.argv[1].lower() if len(sys.argv) > 1 else "all"
target_slug = sys.argv[2] if len(sys.argv) > 2 else ""
try:
    data = json.load(sys.stdin)
    animes = data.get("anime", [])
    if target_slug:
        animes = [a for a in animes if a.get("slug") == target_slug]
    
    idx = 1
    for a in animes:
        anime_name = a.get("name", "Anime")
        for t in a.get("animethemes", []):
            ttype = (t.get("type") or (t.get("slug")[:2] if t.get("slug") else "") or "OP").upper()
            slug_tag = t.get("slug") or ttype
            
            if filter_type == "op" and not ttype.startswith("OP"):
                continue
            if filter_type == "ed" and not ttype.startswith("ED"):
                continue
                
            song = t.get("song") or {}
            song_title = song.get("title") or "Theme Song"
            artists = ", ".join([art.get("name", "") for art in song.get("artists", []) if art.get("name")])
            artist_str = f" - {artists}" if artists else ""

            for entry in t.get("animethemeentries", []):
                for v in entry.get("videos", []):
                    link = v.get("link") or (v.get("audio") or {}).get("link")
                    if not link:
                        continue
                    res = v.get("resolution") or 720
                    tags = v.get("tags") or ""
                    tag_str = f" [{tags}]" if tags else ""
                    label = f"[{slug_tag}] '{song_title}'{artist_str} ({res}p{tag_str})"
                    print(f"{idx}	{link}	{label}	{anime_name} - {slug_tag}: {song_title}")
                    idx += 1
except Exception:
    sys.exit(1)
' "$_type_filter" "$_target_slug" 2>/dev/null
    fi
}

themes_play_track() {
    _url="$1"
    _title="$2"
    _is_audio_only="${3:-0}"

    [ -z "$_url" ] && return 1

    if [ "${SRANIME_CLI_PLAYER:-$player}" = "debug" ]; then
        printf "DEBUG_THEME_PLAY: url=%s title=%s audio_only=%s
" "$_url" "$_title" "$_is_audio_only"
        return 0
    fi

    case "${player:-mpv}" in
        mpv)
            if [ "$_is_audio_only" = "1" ]; then
                mpv --no-video --force-media-title="$_title" "$_url"
            else
                mpv --force-media-title="$_title" "$_url"
            fi
            ;;
        vlc)
            if [ "$_is_audio_only" = "1" ]; then
                vlc --intf dummy --novideo "$_url" vlc://quit 2>/dev/null
            else
                vlc --meta-title "$_title" "$_url" 2>/dev/null
            fi
            ;;
        *)
            if command -v mpv >/dev/null 2>&1; then
                if [ "$_is_audio_only" = "1" ]; then
                    mpv --no-video --force-media-title="$_title" "$_url"
                else
                    mpv --force-media-title="$_title" "$_url"
                fi
            else
                printf "Error: No suitable media player found for theme playback.\n" >&2
                return 1
            fi
            ;;
    esac
}

themes_download_track() {
    _url="$1"
    _filename="$2"

    [ -z "$_url" ] && return 1
    [ -z "$_filename" ] && _filename="theme_track.webm"

    if [ "${SRANIME_CLI_PLAYER:-$player}" = "debug" ]; then
        printf "DEBUG_THEME_DOWNLOAD: url=%s filename=%s
" "$_url" "$_filename"
        return 0
    fi

    if command -v aria2c >/dev/null 2>&1; then
        aria2c -c -x 16 -s 16 -o "$_filename" "$_url"
    else
        curl -sL "$_url" -o "$_filename"
    fi
}

themes_interactive() {
    _query="$1"
    _type_filter="${2:-all}"
    _is_audio_only="${3:-0}"
    _download_mode="${4:-0}"

    if [ -z "$_query" ]; then
        printf "Enter anime title to search themes: "
        read -r _query
    fi
    [ -z "$_query" ] && return 1

    printf "Searching AnimeThemes for '%s'...
" "$_query"
    _json=$(themes_search "$_query")
    [ -z "$_json" ] && { printf "No themes found for '%s'.
" "$_query"; return 1; }

    _anime_list=$(themes_parse_anime_list "$_json")
    [ -z "$_anime_list" ] && { printf "No matching anime found.
"; return 1; }

    _selected_anime=$(printf "%s
" "$_anime_list" | menu "Select anime: ")
    [ -z "$_selected_anime" ] && return 0

    _slug=$(printf "%s" "$_selected_anime" | cut -f2)
    _tracks=$(themes_extract_tracks "$_json" "$_type_filter" "$_slug")
    [ -z "$_tracks" ] && { printf "No matching tracks found for this anime.
"; return 1; }

    _selected_track=$(printf "%s
" "$_tracks" | menu "Select theme song: ")
    [ -z "$_selected_track" ] && return 0

    _video_url=$(printf "%s" "$_selected_track" | cut -f2)
    _track_title=$(printf "%s" "$_selected_track" | cut -f4)
    [ -z "$_track_title" ] && _track_title=$(printf "%s" "$_selected_track" | cut -f3)

    if [ "$_download_mode" = "1" ]; then
        _clean_title=$(printf "%s" "$_track_title" | tr -d '":/\*?<>|' | tr ' ' '_')
        _out_file="${_clean_title}.webm"
        printf "Downloading theme: %s -> %s
" "$_track_title" "$_out_file"
        themes_download_track "$_video_url" "$_out_file"
    else
        printf "Playing theme: %s
" "$_track_title"
        themes_play_track "$_video_url" "$_track_title" "$_is_audio_only"
    fi
}
