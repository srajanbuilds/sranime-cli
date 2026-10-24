#!/bin/sh
# sranime-cli playback module — timestamp resumption, checkpoints, and binge autoplay
#
# Provides:
#   - playback_format_time <seconds>
#   - playback_parse_time <time_str>
#   - playback_save_checkpoint <anime_title> <ep_no> <seconds> <percent>
#   - playback_get_checkpoint <anime_title> [ep_no]
#   - playback_clear_checkpoint <anime_title>
#   - playback_list_checkpoints
#   - playback_prepare_observer <scrobble_trig> <pos_trig>

_checkpoint_dir="${SRANIME_CLI_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}"
_checkpoint_file="${_checkpoint_dir}/checkpoints.tsv"

_ensure_checkpoint_dir() {
    [ ! -d "$_checkpoint_dir" ] && mkdir -p "$_checkpoint_dir" 2>/dev/null || true
    [ ! -f "$_checkpoint_file" ] && : >"$_checkpoint_file" 2>/dev/null || true
}

# Convert integer seconds into HH:MM:SS or MM:SS format
playback_format_time() {
    _sec="${1:-0}"
    _sec=$(printf "%s" "$_sec" | grep -o '^[0-9]\+' || echo 0)
    [ -z "$_sec" ] && _sec=0

    _hrs=$(( _sec / 3600 ))
    _rem=$(( _sec % 3600 ))
    _mins=$(( _rem / 60 ))
    _secs=$(( _rem % 60 ))

    if [ "$_hrs" -gt 0 ]; then
        printf "%02d:%02d:%02d" "$_hrs" "$_mins" "$_secs"
    else
        printf "%02d:%02d" "$_mins" "$_secs"
    fi
}

# Parse MM:SS, HH:MM:SS, or raw integer seconds into integer seconds
playback_parse_time() {
    _raw="$1"
    [ -z "$_raw" ] && printf "0" && return 0

    case "$_raw" in
        *:*:*)
            _h=$(printf "%s" "$_raw" | cut -d: -f1)
            _m=$(printf "%s" "$_raw" | cut -d: -f2)
            _s=$(printf "%s" "$_raw" | cut -d: -f3)
            printf "%d" "$(( (_h * 3600) + (_m * 60) + _s ))"
            ;;
        *:*)
            _m=$(printf "%s" "$_raw" | cut -d: -f1)
            _s=$(printf "%s" "$_raw" | cut -d: -f2)
            printf "%d" "$(( (_m * 60) + _s ))"
            ;;
        *)
            _int=$(printf "%s" "$_raw" | grep -o '^[0-9]\+' || echo 0)
            printf "%d" "${_int:-0}"
            ;;
    esac
}

# Save or update active anime playback position checkpoint
# TSV schema: Anime Title 	 Episode Number 	 Seconds 	 Formatted Time 	 Percent 	 ISO8601 Timestamp
playback_save_checkpoint() {
    _title="$1"
    _ep="$2"
    _seconds="${3:-0}"
    _percent="${4:-0}"

    [ -z "$_title" ] || [ -z "$_ep" ] && return 1
    _ensure_checkpoint_dir

    _clean_sec=$(printf "%s" "$_seconds" | grep -o '^[0-9]\+' || echo 0)
    _fmt_time=$(playback_format_time "$_clean_sec")
    _now=$(date +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "2026-09-28T00:00:00Z")

    _tmp="${_checkpoint_file}.tmp.$$"
    # Remove existing checkpoint for this title
    if [ -f "$_checkpoint_file" ]; then
        grep -v "^${_title}	" "$_checkpoint_file" > "$_tmp" 2>/dev/null || true
    else
        : > "$_tmp"
    fi

    # Append new checkpoint if position > 5 seconds
    if [ "${_clean_sec:-0}" -ge 5 ]; then
        printf "%s	%s	%s	%s	%s	%s
" "$_title" "$_ep" "$_clean_sec" "$_fmt_time" "$_percent" "$_now" >> "$_tmp"
    fi

    mv -f "$_tmp" "$_checkpoint_file" 2>/dev/null || cp -f "$_tmp" "$_checkpoint_file" 2>/dev/null || true
    rm -f "$_tmp" 2>/dev/null || true
}

# Retrieve checkpoint for anime
# Returns: ep_no 	 seconds 	 formatted_time 	 percent
playback_get_checkpoint() {
    _title="$1"
    _target_ep="$2"

    [ -z "$_title" ] && return 1
    [ ! -f "$_checkpoint_file" ] && return 1

    _entry=$(grep "^${_title}	" "$_checkpoint_file" 2>/dev/null | tail -n 1 || true)
    [ -z "$_entry" ] && return 1

    _c_ep=$(printf "%s" "$_entry" | cut -f2)
    _c_sec=$(printf "%s" "$_entry" | cut -f3)
    _c_fmt=$(printf "%s" "$_entry" | cut -f4)
    _c_pct=$(printf "%s" "$_entry" | cut -f5)

    if [ -n "$_target_ep" ] && [ "$_target_ep" != "$_c_ep" ]; then
        return 1
    fi

    printf "%s	%s	%s	%s
" "$_c_ep" "$_c_sec" "$_c_fmt" "$_c_pct"
    return 0
}

# Clear checkpoint for a specific anime
playback_clear_checkpoint() {
    _title="$1"
    [ -z "$_title" ] || [ ! -f "$_checkpoint_file" ] && return 0

    _tmp="${_checkpoint_file}.tmp.$$"
    grep -v "^${_title}	" "$_checkpoint_file" > "$_tmp" 2>/dev/null || true
    mv -f "$_tmp" "$_checkpoint_file" 2>/dev/null || cp -f "$_tmp" "$_checkpoint_file" 2>/dev/null || true
    rm -f "$_tmp" 2>/dev/null || true
}

# List all saved anime in-progress checkpoints
playback_list_checkpoints() {
    _ensure_checkpoint_dir
    if [ ! -s "$_checkpoint_file" ]; then
        printf "[1;33mNo in-progress anime checkpoints found.[0m
"
        printf "Watch progress is automatically saved when pausing or closing player.
"
        return 0
    fi

    printf "[1;36m================== In-Progress Anime Checkpoints ==================[0m

"
    printf "  [1m%-34s %-8s %-12s %-8s[0m
" "Anime Title" "Episode" "Position" "Progress"
    printf "  %-34s %-8s %-12s %-8s
" "----------------------------------" "-------" "------------" "--------"

    while IFS="	" read -r _title _ep _sec _fmt _pct _date; do
        [ -z "$_title" ] && continue
        printf "  [1;37m%-34s[0m [1;34mEp %-5s[0m [1;33m%-12s[0m [1;32m%s%%[0m
"             "$(printf "%.34s" "$_title")" "$_ep" "$_fmt" "$_pct"
    done < "$_checkpoint_file"
    printf "
[0;90mRun 'sranime-cli -R "<title>"' to resume playback instantly.[0m
"
}

# Prepare unified MPV Lua script for both scrobbling and playback position tracking
# Usage: playback_prepare_observer <scrobble_trig_path> <position_trig_path>
playback_prepare_observer() {
    _scrobble_trig="$1"
    _pos_trig="$2"

    [ -z "$_scrobble_trig" ] || [ -z "$_pos_trig" ] && return 1

    _lua_file="${_pos_trig}.lua"
    _clean_scrobble=$(printf "%s" "$_scrobble_trig" | sed 's|\\|/|g')
    _clean_pos=$(printf "%s" "$_pos_trig" | sed 's|\\|/|g')
    if command -v cygpath >/dev/null 2>&1; then
        _clean_scrobble=$(cygpath -m "$_scrobble_trig" 2>/dev/null || printf "%s" "$_clean_scrobble")
        _clean_pos=$(cygpath -m "$_pos_trig" 2>/dev/null || printf "%s" "$_clean_pos")
    fi

    cat << LUAEOF > "$_lua_file"
-- sranime-cli unified MPV observer: 80% scrobble & timestamp position checkpoint
local scrobble_path = [=[$_clean_scrobble]=]
local position_path = [=[$_clean_pos]=]
local scrobbled = false

local function trigger_scrobble()
    if not scrobbled then
        scrobbled = true
        local f = io.open(scrobble_path, "w")
        if f then
            f:write("SCROBBLED
")
            f:close()
        end
    end
end

local function save_position()
    local pos = mp.get_property_number("time-pos")
    local pct = mp.get_property_number("percent-pos")
    if pos and pos > 5 then
        local f = io.open(position_path, "w")
        if f then
            f:write(string.format("%d	%.1f
", math.floor(pos), pct or 0))
            f:close()
        end
    end
end

-- 80% Progress Watcher
mp.observe_property("percent-pos", "number", function(_, val)
    if val and val >= 80 then
        trigger_scrobble()
    end
end)

-- End of File
mp.register_event("end-file", function(event)
    if event and event.reason == "eof" then
        trigger_scrobble()
        -- Mark as finished by writing EOF
        local f = io.open(position_path, "w")
        if f then
            f:write("EOF	100
")
            f:close()
        end
    end
end)

-- Periodic position update (every 10 seconds)
mp.add_periodic_timer(10, save_position)

-- In-Player Hotkeys N/P/B/S & OSD HUD
local function show_welcome_hud()
    local title = mp.get_property("media-title") or "Anime Episode"
    mp.osd_message(string.format("▶ %s\n[N] Next Ep  •  [P] Prev Ep  •  [B] Bookmark", title), 4)
end

mp.add_forced_key_binding("n", "sranime_next", function()
    mp.osd_message("⏭ Advancing to Next Episode...", 2)
    save_position()
    mp.commandv("quit", "101")
end)
mp.add_forced_key_binding("N", "sranime_next_shift", function()
    mp.osd_message("⏭ Advancing to Next Episode...", 2)
    save_position()
    mp.commandv("quit", "101")
end)
mp.add_forced_key_binding("p", "sranime_prev", function()
    mp.osd_message("⏮ Returning to Previous Episode...", 2)
    save_position()
    mp.commandv("quit", "102")
end)
mp.add_forced_key_binding("P", "sranime_prev_shift", function()
    mp.osd_message("⏮ Returning to Previous Episode...", 2)
    save_position()
    mp.commandv("quit", "102")
end)
mp.add_forced_key_binding("b", "sranime_bookmark", function()
    save_position()
    local pos = mp.get_property_number("time-pos", 0)
    local mins = math.floor(pos / 60)
    local secs = math.floor(pos % 60)
    mp.osd_message(string.format("★ Bookmark saved at %02d:%02d", mins, secs), 3)
end)
mp.add_forced_key_binding("B", "sranime_bookmark_shift", function()
    save_position()
    local pos = mp.get_property_number("time-pos", 0)
    local mins = math.floor(pos / 60)
    local secs = math.floor(pos % 60)
    mp.osd_message(string.format("★ Bookmark saved at %02d:%02d", mins, secs), 3)
end)
mp.add_forced_key_binding("s", "sranime_cycle_sub", function()
    mp.commandv("cycle", "sub")
    mp.osd_message("💬 Cycled Subtitle Track", 2)
end)

mp.register_event("file-loaded", show_welcome_hud)

-- Player Shutdown / Exit
mp.register_event("shutdown", save_position)
LUAEOF

    printf "%s" "$_lua_file"
}
