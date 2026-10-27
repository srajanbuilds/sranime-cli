#!/bin/sh
# sranime-cli Offline Mode & Local Vault Player module
# Zero-network offline viewing of local downloads with checkpoint resumption.
#
# Provides:
#   - offline_scan_library [path]
#   - offline_list_shows [path]
#   - offline_list_episodes [path] <show_name>
#   - offline_play_file <file_path> [show_title] [ep_num]
#   - offline_interactive [path]

_offline_default_dir="${download_dir:-${XDG_DATA_HOME:-$HOME/.local/share}/sranime-cli}"

# Scan directory recursively and list video files
# Emits TSV: file_path 	 show_title 	 episode_num 	 file_size
offline_scan_library() {
    _dir="${1:-$_offline_default_dir}"
    [ ! -d "$_dir" ] && return 1

    if command -v python >/dev/null 2>&1; then
        python -c '
import os, sys, re

scan_dir = sys.argv[1]
exts = (".mp4", ".mkv", ".webm", ".avi", ".ts")

for root, _, files in os.walk(scan_dir):
    for f in sorted(files):
        if f.lower().endswith(exts):
            full_path = os.path.join(root, f)
            size_mb = os.path.getsize(full_path) // (1024 * 1024)
            
            # Detect show name from folder or filename
            # Patterns: "Show Name - S01E04 - [1080p].mp4" or "Show/Season 01/Ep 04.mp4"
            show = "Unknown Anime"
            ep = "1"
            
            # Check S01E04 pattern
            m = re.search(r"^(.*?)\s*-\s*[Ss](\d+)[Ee](\d+)", f)
            if m:
                show = m.group(1).strip()
                ep = str(int(m.group(3)))
            else:
                m2 = re.search(r"[Ee][Pp]?\s*(\d+)", f)
                if m2:
                    ep = str(int(m2.group(1)))
                    # Use parent directory as show name if reasonable
                    parent = os.path.basename(root)
                    if not parent.lower().startswith("season") and parent != os.path.basename(scan_dir):
                        show = parent
                    else:
                        grandparent = os.path.basename(os.path.dirname(root))
                        if grandparent != os.path.basename(scan_dir):
                            show = grandparent
                else:
                    show = os.path.splitext(f)[0]
                    
            print(f"{full_path}	{show}	{ep}	{size_mb}MB")
' "$_dir" 2>/dev/null
    fi
}

# List all unique anime shows in offline vault
# Output: <index>	<show_title>	<show_title> (<count> episodes offline)
offline_list_shows() {
    _dir="${1:-$_offline_default_dir}"
    _scan=$(offline_scan_library "$_dir")
    [ -z "$_scan" ] && return 1

    if command -v python >/dev/null 2>&1; then
        printf '%s' "$_scan" | python -c '
import sys
from collections import Counter

shows = Counter()
for line in sys.stdin:
    parts = line.strip().split("	")
    if len(parts) >= 2:
        shows[parts[1]] += 1

for idx, (show, count) in enumerate(sorted(shows.items()), 1):
    print(f"{idx}	{show}	{show} ({count} episodes offline)")
' 2>/dev/null
    fi
}

# List episodes for a specific show
# Output: <index>	<file_path>	<display_label>	<ep_num>
offline_list_episodes() {
    _dir="${1:-$_offline_default_dir}"
    _target_show="$2"
    _scan=$(offline_scan_library "$_dir")
    [ -z "$_scan" ] && return 1

    if command -v python >/dev/null 2>&1; then
        printf '%s' "$_scan" | python -c '
import sys

target = sys.argv[1] if len(sys.argv) > 1 else ""
idx = 1
for line in sys.stdin:
    parts = line.strip().split("	")
    if len(parts) >= 4:
        fpath, show, ep, size = parts[0], parts[1], parts[2], parts[3]
        if not target or show.lower() == target.lower():
            fname = fpath.replace("\\", "/").split("/")[-1]
            label = f"Episode {ep:0>2} ({size}) - {fname}"
            print(f"{idx}	{fpath}	{label}	{ep}")
            idx += 1
' "$_target_show" 2>/dev/null
    fi
}

# Play local file with sidecar subtitles & checkpoints
offline_play_file() {
    _file="$1"
    _show="${2:-Local Anime}"
    _ep="${3:-1}"

    [ ! -f "$_file" ] && return 1

    # Check for sidecar subtitle (.vtt, .srt, .ass)
    _base="${_file%.*}"
    _sub_opt=""
    for _cand_sub in "${_base}.vtt" "${_base}.srt" "${_base}.ass" "${_base}.en.vtt" "${_base}.en.srt"; do
        if [ -f "$_cand_sub" ]; then
            _sub_opt="$_cand_sub"
            break
        fi
    done

    # Check for checkpoint resume
    _start_sec=""
    if command -v playback_get_checkpoint >/dev/null 2>&1; then
        _start_sec=$(playback_get_checkpoint "$_show" "$_ep")
    fi

    if [ "${SRANIME_CLI_PLAYER:-$player}" = "debug" ]; then
        printf "DEBUG_OFFLINE_PLAY: file=%s show=%s ep=%s sub=%s start=%s
"             "$_file" "$_show" "$_ep" "${_sub_opt:-none}" "${_start_sec:-0}"
        return 0
    fi

    # Record to local watch log
    if command -v log_watch_event >/dev/null 2>&1; then
        log_watch_event "$_show" "$_ep" "OFFLINE"
    fi

    case "${SRANIME_CLI_PLAYER:-${player:-mpv}}" in
        debug)
            printf "file=%s sub=%s ep=%s start=%s\n" "$_file" "$_sub_opt" "$_ep" "${_start_sec:-0}"
            return 0
            ;;
        mpv)
            set -- mpv "--force-media-title=${_show} - Ep ${_ep}"
            [ -n "$_sub_opt" ] && set -- "$@" "--sub-file=$_sub_opt"
            [ -n "$_start_sec" ] && [ "$_start_sec" -gt 0 ] && set -- "$@" "--start=$_start_sec"
            set -- "$@" "$_file"
            "$@"
            ;;
        vlc)
            set -- vlc "--meta-title=${_show} - Ep ${_ep}"
            [ -n "$_sub_opt" ] && set -- "$@" "--sub-file=$_sub_opt"
            [ -n "$_start_sec" ] && [ "$_start_sec" -gt 0 ] && set -- "$@" "--start-time=$_start_sec"
            set -- "$@" "$_file"
            "$@"
            ;;
        *)
            if command -v mpv >/dev/null 2>&1; then
                mpv --force-media-title="${_show} - Ep ${_ep}" "$_file"
            else
                printf "Error: No player available for offline playback.
" >&2
                return 1
            fi
            ;;
    esac
}

# Interactive offline library browser
offline_interactive() {
    _dir="${1:-$_offline_default_dir}"
    [ ! -d "$_dir" ] && { printf "Offline vault directory not found: %s
" "$_dir"; return 1; }

    _shows=$(offline_list_shows "$_dir")
    [ -z "$_shows" ] && { printf "No downloaded anime found in vault (%s).
" "$_dir"; return 1; }

    _selected_show=$(printf "%s
" "$_shows" | menu "Select offline anime: ")
    [ -z "$_selected_show" ] && return 0

    _show_title=$(printf "%s" "$_selected_show" | cut -f2)
    _episodes=$(offline_list_episodes "$_dir" "$_show_title")
    [ -z "$_episodes" ] && { printf "No episodes found for %s.
" "$_show_title"; return 1; }

    _selected_ep=$(printf "%s
" "$_episodes" | menu "Select episode: ")
    [ -z "$_selected_ep" ] && return 0

    _file_path=$(printf "%s" "$_selected_ep" | cut -f2)
    _ep_num=$(printf "%s" "$_selected_ep" | cut -f4)

    printf "Launching offline playback: %s (Ep %s)
" "$_show_title" "$_ep_num"
    offline_play_file "$_file_path" "$_show_title" "$_ep_num"
}
