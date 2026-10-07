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
                $_extra_flags \
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
                $_extra_flags \
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
