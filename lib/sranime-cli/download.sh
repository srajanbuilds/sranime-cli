#!/bin/sh
# sranime-cli download module — accelerated downloading engine with aria2c multi-connection chunking
#
# Provides:
#   - sanitize_filename <title>
#   - detect_best_downloader <stream_url>
#   - download_stream <url> <title> <out_dir> [sub_url] [extra_flags]

# Sanitize string for cross-platform filesystem safety
sanitize_filename() {
    _raw="$1"
    # Replace slashes and colons with dashes; strip quotes, brackets, and illegal symbols
    printf '%s' "$_raw" | \
        sed -e 's|[/\\:]| - |g' \
            -e 's/[*?"<>|]//g' \
            -e 's/[[:space:]]\+/ /g' \
            -e 's/^[[:space:]]*//' \
            -e 's/[[:space:]]*$//' \
            -e 's/ - - / - /g'
}
download_sanitize_filename() { sanitize_filename "$@"; }

# Determine optimal downloader binary for the given stream URL
# HLS (.m3u8) streams require yt-dlp or ffmpeg
# Direct MP4/HLS streams with aria2c get 16 parallel connections
detect_best_downloader() {
    _url="$1"
    case "$_url" in
        *.m3u8* | *m3u8*)
            if command -v yt-dlp >/dev/null 2>&1; then
                printf "yt-dlp"
            elif command -v ffmpeg >/dev/null 2>&1; then
                printf "ffmpeg"
            elif command -v aria2c >/dev/null 2>&1; then
                printf "aria2c"
            else
                printf "curl"
            fi
            ;;
        *)
            if command -v aria2c >/dev/null 2>&1; then
                printf "aria2c"
            elif command -v yt-dlp >/dev/null 2>&1; then
                printf "yt-dlp"
            elif command -v ffmpeg >/dev/null 2>&1; then
                printf "ffmpeg"
            else
                printf "curl"
            fi
            ;;
    esac
}

# Format rate limit flags across download engines
download_format_rate_limit() {
    _tool="$1"
    _rate="$2"
    [ -z "$_rate" ] && return 0
    case "$_tool" in
        aria2c) printf "%s" "--max-download-limit=$_rate" ;;
        yt-dlp|curl) printf "%s" "--limit-rate $_rate" ;;
        *) ;;
    esac
}

# Execute accelerated stream download with fallback
download_stream() {
    _url="$1"
    _title="$2"
    _out_dir="${3:-.}"
    _sub_url="$4"
    _extra_flags="$5"

    [ -z "$_url" ] && return 1
    [ ! -d "$_out_dir" ] && mkdir -p "$_out_dir" 2>/dev/null || true

    _safe_name=$(sanitize_filename "$_title")
    [ -z "$_safe_name" ] && _safe_name="anime_download"

    _target_file="${_out_dir}/${_safe_name}.mp4"
    _part_file="${_out_dir}/${_safe_name}.part"

    # Download subtitles if available
    if [ -n "$_sub_url" ]; then
        _vtt_file="${_out_dir}/${_safe_name}.vtt"
        curl -sL -A "Mozilla/5.0" --max-time 10 "$_sub_url" -o "$_vtt_file" 2>/dev/null || true
    fi

    _agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    _refr="${refr:-https://hianime.at/}"

    _dl_tool=$(detect_best_downloader "$_url")
    _rate_flag=""
    [ -n "${max_rate:-}" ] && _rate_flag=$(download_format_rate_limit "$_dl_tool" "$max_rate")
    _status=1

    printf "\033[1;36m==> Downloading:\033[0m %s\n" "$_safe_name"
    printf "  Destination : %s\n" "$_target_file"
    printf "  Engine      : \033[1;32m%s\033[0m\n" "$_dl_tool"

    case "$_dl_tool" in
        aria2c)
            printf "  Accelerating with up to 16 concurrent connections...\n"
            if aria2c \
                --max-connection-per-server=16 \
                --split=16 \
                --min-split-size=1M \
                --continue=true \
                --auto-file-renaming=false \
                --allow-overwrite=true \
                --user-agent="$_agent" \
                --header="Referer: $_refr" \
                --dir="$_out_dir" \
                --out="${_safe_name}.part" \
                $_extra_flags $_rate_flag \
                "$_url"; then
                mv -f "$_part_file" "$_target_file" 2>/dev/null || true
                _status=0
            fi
            ;;
        yt-dlp)
            if yt-dlp \
                --concurrent-fragments 16 \
                --no-part \
                --add-header "Referer:$_refr" \
                --user-agent "$_agent" \
                -o "$_target_file" \
                $_extra_flags $_rate_flag \
                "$_url"; then
                _status=0
            fi
            ;;
        ffmpeg)
            if ffmpeg -extension_picky 0 \
                -headers "Referer: $_refr" \
                -headers "User-Agent: $_agent" \
                -y -loglevel error -stats \
                -i "$_url" \
                -c copy -bsf:a aac_adtstoasc \
                $_extra_flags \
                "$_target_file"; then
                _status=0
            fi
            ;;
        *)
            if curl -C - -sL \
                -A "$_agent" \
                -e "$_refr" \
                -o "$_target_file" \
                "$_url"; then
                _status=0
            fi
            ;;
    esac

    # Fallback to secondary downloaders if primary failed
    if [ "$_status" -ne 0 ]; then
        printf "\033[1;33mPrimary engine %s failed. Trying fallback...\033[0m\n" "$_dl_tool"
        if command -v yt-dlp >/dev/null 2>&1 && [ "$_dl_tool" != "yt-dlp" ]; then
            if yt-dlp --concurrent-fragments 8 --add-header "Referer:$_refr" -o "$_target_file" "$_url"; then
                _status=0
            fi
        fi
        if [ "$_status" -ne 0 ] && command -v ffmpeg >/dev/null 2>&1 && [ "$_dl_tool" != "ffmpeg" ]; then
            if ffmpeg -extension_picky 0 -headers "Referer: $_refr" -y -loglevel error -stats -i "$_url" -c copy "$_target_file"; then
                _status=0
            fi
        fi
    fi

    if [ "$_status" -eq 0 ] && [ -s "$_target_file" ]; then
        printf "\033[1;32m✓ Download completed successfully:\033[0m %s\n" "$_target_file"
        if [ "${enable_nfo:-0}" = "1" ]; then
            _lib_dir="${SRANIME_LIB_DIR:-lib/sranime-cli}"
            [ -f "$_lib_dir/nfo.sh" ] && . "$_lib_dir/nfo.sh" 2>/dev/null || true
            nfo_enrich_and_generate "$_target_file" "$_title" "${ep_no:-1}" "${season_no:-1}" "${poster_url:-}" "$_sub_url" 2>/dev/null || true
        fi
        if command -v notify_download_complete >/dev/null 2>&1; then
            notify_download_complete "$_title" "${ep_no:-1}" "$_out_dir"
        fi
        return 0
    else
        printf "\033[1;31m✗ Download failed for %s\033[0m\n" "$_title" >&2
        rm -f "$_part_file" 2>/dev/null || true
        return 1
    fi
}

# Parse episode ranges into sorted, unique episode list
# Supports: "1-12", "1,3,5-8", "all", "1 2 3"
# Usage: parse_episode_range <range_str> [max_episodes]
parse_episode_range() {
    _range="$1"
    _max="${2:-1000}"
    [ -z "$_range" ] && return 1

    printf '%s\n' "$_range" | tr ',' ' ' | tr -s ' ' '\n' | while read -r _part; do
        [ -z "$_part" ] && continue
        case "$_part" in
            all)
                _i=1
                while [ "$_i" -le "$_max" ]; do
                    printf "%d\n" "$_i"
                    _i=$((_i + 1))
                done
                ;;
            *-*)
                _start="${_part%%-*}"
                _end="${_part##*-}"
                case "$_start" in ''|*[!0-9]*) continue ;; esac
                case "$_end" in ''|*[!0-9]*) continue ;; esac
                if [ "$_start" -le "$_end" ]; then
                    _i="$_start"
                    while [ "$_i" -le "$_end" ]; do
                        printf "%d\n" "$_i"
                        _i=$((_i + 1))
                    done
                fi
                ;;
            *)
                case "$_part" in
                    ''|*[!0-9]*) continue ;;
                    *) printf "%d\n" "$_part" ;;
                esac
                ;;
        esac
    done | sort -nu
}

# Format standardized Plex/Jellyfin file path
# Usage: format_season_path <download_base> <anime_title> <ep_no> [season_no] [quality]
format_season_path() {
    _base="${1:-.}"
    _title="$2"
    _ep="$3"
    _season="${4:-1}"
    _qual="${5:-1080p}"

    _safe_title=$(sanitize_filename "$_title")
    _s_pad=$(printf "%02d" "$_season" 2>/dev/null || printf "%s" "$_season")
    _e_pad=$(printf "%02d" "$_ep" 2>/dev/null || printf "%s" "$_ep")

    printf "%s/%s/Season %s/%s - S%sE%s [%s].mp4" \
        "$_base" "$_safe_title" "$_s_pad" "$_safe_title" "$_s_pad" "$_e_pad" "$_qual"
}

# Format display summary for batch download queue
# Usage: download_batch_summary <ep_list>
download_batch_summary() {
    _list="$1"
    _count=$(printf '%s\n' "$_list" | wc -l | tr -d '[:space:]')
    printf "\033[1;36m================ Batch Download Queue ================\033[0m\n"
    printf "  Total Episodes : \033[1;33m%s\033[0m\n" "$_count"
    printf "  Queue List     : \033[1;32m%s\033[0m\n" "$(printf '%s ' $_list)"
    printf "  Concurrency    : \033[1;35m%s worker(s)\033[0m\n" "${SRANIME_DOWNLOAD_CONCURRENCY:-2}"
    printf "\033[1;36m======================================================\033[0m\n"
}
