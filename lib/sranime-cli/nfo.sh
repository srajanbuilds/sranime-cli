#!/bin/sh
# sranime-cli nfo module — Jellyfin, Plex & Kodi metadata and artwork generation
#
# Provides:
#   - nfo_generate_tvshow <series_dir> <title> [jname] [synopsis] [year] [studio] [genres] [score] [anilist_id] [mal_id]
#   - nfo_generate_episode <target_nfo> <title> <ep_no> [ep_title] [synopsis] [season_no]
#   - nfo_fetch_artwork <series_dir> <poster_url> [banner_url]
#   - nfo_save_subtitles <sub_url> <video_file> [lang]
#   - nfo_enrich_and_generate <video_file> <title> <ep_no> [season_no] [poster_url] [sub_url]

# Generate standard tvshow.nfo in series directory
nfo_generate_tvshow() {
    _out_dir="$1"
    _title="$2"
    _jname="${3:-$_title}"
    _synopsis="${4:-No synopsis available.}"
    _year="${5:-}"
    _studio="${6:-Animation}"
    _genres="${7:-Anime}"
    _score="${8:-}"
    _anilist_id="${9:-0}"
    _mal_id="${10:-0}"

    [ -z "$_out_dir" ] || [ -z "$_title" ] && return 1
    mkdir -p "$_out_dir" 2>/dev/null || true
    _nfo_file="${_out_dir}/tvshow.nfo"

    # Clean XML special characters in title and synopsis
    _clean_plot=$(printf '%s' "$_synopsis" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
    _clean_title=$(printf '%s' "$_title" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
    _clean_jname=$(printf '%s' "$_jname" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')

    cat << NFOEOF > "$_nfo_file"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<tvshow>
  <title>$_clean_title</title>
  <originaltitle>$_clean_jname</originaltitle>
  <plot>$_clean_plot</plot>
  <studio>$_studio</studio>
NFOEOF

    [ -n "$_year" ] && printf "  <year>%s</year>\n" "$_year" >> "$_nfo_file"

    # Write genres
    IFS=','
    for g in $_genres; do
        _cg=$(printf '%s' "$g" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -n "$_cg" ] && printf "  <genre>%s</genre>\n" "$_cg" >> "$_nfo_file"
    done
    unset IFS

    [ -n "$_score" ] && printf "  <rating>%s</rating>\n" "$_score" >> "$_nfo_file"

    cat << NFOEOF >> "$_nfo_file"
  <status>Continuing</status>
  <uniqueid type="anilist" default="true">$_anilist_id</uniqueid>
  <uniqueid type="mal">$_mal_id</uniqueid>
</tvshow>
NFOEOF
    printf "\033[1;32m✓ Generated tvshow.nfo for:\033[0m %s\n" "$_title"
}

# Generate individual episode .nfo file alongside video
nfo_generate_episode() {
    _target_nfo="$1"
    _title="$2"
    _ep="$3"
    _ep_title="${4:-Episode $3}"
    _synopsis="${5:-}"
    _season="${6:-1}"

    [ -z "$_target_nfo" ] || [ -z "$_title" ] || [ -z "$_ep" ] && return 1
    mkdir -p "$(dirname "$_target_nfo")" 2>/dev/null || true

    _clean_eptitle=$(printf '%s' "$_ep_title" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
    _clean_plot=$(printf '%s' "${_synopsis:-$_title - Episode $_ep}" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')

    cat << NFOEOF > "$_target_nfo"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<episodedetails>
  <title>$_clean_eptitle</title>
  <season>$_season</season>
  <episode>$_ep</episode>
  <plot>$_clean_plot</plot>
</episodedetails>
NFOEOF
}

# Fetch poster.jpg and fanart.jpg into series directory
nfo_fetch_artwork() {
    _out_dir="$1"
    _poster_url="$2"
    _banner_url="$3"

    [ -z "$_out_dir" ] && return 1
    mkdir -p "$_out_dir" 2>/dev/null || true

    _agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

    if [ -n "$_poster_url" ] && [ ! -f "${_out_dir}/poster.jpg" ]; then
        curl -sL --max-time 12 -A "$_agent" "$_poster_url" -o "${_out_dir}/poster.jpg" 2>/dev/null || true
    fi

    if [ -n "$_banner_url" ] && [ ! -f "${_out_dir}/fanart.jpg" ]; then
        curl -sL --max-time 12 -A "$_agent" "$_banner_url" -o "${_out_dir}/fanart.jpg" 2>/dev/null || true
    fi
}

# Save external subtitle sidecar formatted to Plex/Jellyfin conventions
nfo_save_subtitles() {
    _sub_url="$1"
    _video_file="$2"
    _lang="${3:-en}"

    [ -z "$_sub_url" ] || [ -z "$_video_file" ] && return 1

    # Base path without .mp4 or other video extension
    _base="${_video_file%.*}"
    _sidecar="${_base}.${_lang}.vtt"

    _agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    if curl -sL --max-time 15 -A "$_agent" "$_sub_url" -o "$_sidecar" 2>/dev/null; then
        if [ -s "$_sidecar" ]; then
            printf "\033[1;32m✓ Saved subtitle sidecar:\033[0m %s\n" "$_sidecar"
            return 0
        fi
    fi
    rm -f "$_sidecar" 2>/dev/null || true
    return 1
}

# High-level orchestrator called after video download
nfo_enrich_and_generate() {
    _video_file="$1"
    _title="$2"
    _ep="$3"
    _season="${4:-1}"
    _poster_url="$5"
    _sub_url="$6"

    [ -z "$_video_file" ] || [ -z "$_title" ] || [ -z "$_ep" ] && return 1

    _vid_dir=$(dirname "$_video_file")
    # If Season XX directory, parent is series directory
    case "$_vid_dir" in
        */Season* | *\Season*) _series_dir=$(dirname "$_vid_dir") ;;
        *)                      _series_dir="$_vid_dir" ;;
    esac

    # 1. tvshow.nfo
    if [ ! -f "${_series_dir}/tvshow.nfo" ]; then
        nfo_generate_tvshow "$_series_dir" "$_title" "$_title" "" "" "" "Anime" "" "0" "0"
    fi

    # 2. Episode .nfo
    _ep_nfo="${_video_file%.*}.nfo"
    nfo_generate_episode "$_ep_nfo" "$_title" "$_ep" "Episode $_ep" "" "$_season"

    # 3. Artwork
    if [ -n "$_poster_url" ]; then
        nfo_fetch_artwork "$_series_dir" "$_poster_url" ""
    fi

    # 4. Subtitles
    if [ -n "$_sub_url" ]; then
        nfo_save_subtitles "$_sub_url" "$_video_file" "en"
    fi
}
