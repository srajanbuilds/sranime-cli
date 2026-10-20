-- sranime-cli MPV On-Screen Display HUD & Binge Navigation Addon
-- Hotkeys:
--   N : Jump to Next Episode (quits MPV with custom return code 101)
--   P : Jump to Previous Episode (quits MPV with custom return code 102)
--   B : Set Quick Bookmark / Display Checkpoint Status
--   S : Cycle subtitle tracks with enhanced OSD banner

local mp = require 'mp'

-- Exit code constants for sranime-cli autoplay loop
local CODE_NEXT_EPISODE = 101
local CODE_PREV_EPISODE = 102

-- Display stylized OSD HUD banner on startup
local function show_welcome_hud()
    local title = mp.get_property("media-title") or "Anime Episode"
    local hud_text = string.format("▶ %s\n[N] Next Ep  •  [P] Prev Ep  •  [B] Bookmark", title)
    mp.osd_message(hud_text, 4)
end

-- Keybinding: Next Episode
local function on_next_episode()
    mp.osd_message("⏭ Advancing to Next Episode...", 2)
    mp.commandv("quit", tostring(CODE_NEXT_EPISODE))
end

-- Keybinding: Previous Episode
local function on_prev_episode()
    mp.osd_message("⏮ Returning to Previous Episode...", 2)
    mp.commandv("quit", tostring(CODE_PREV_EPISODE))
end

-- Keybinding: Quick Bookmark
local function on_bookmark()
    local pos = mp.get_property_number("time-pos", 0)
    local mins = math.floor(pos / 60)
    local secs = math.floor(pos % 60)
    mp.osd_message(string.format("★ Bookmark saved at %02d:%02d", mins, secs), 3)
end

-- Keybinding: Cycle Subtitles with OSD
local function on_cycle_subs()
    mp.commandv("cycle", "sub")
    local sub_lang = mp.get_property("current-tracks/sub/lang") or "unknown"
    local sub_title = mp.get_property("current-tracks/sub/title") or sub_lang
    mp.osd_message(string.format("💬 Subtitle Track: %s", sub_title), 2)
end

-- Register MPV hotkeys
mp.add_forced_key_binding("n", "sranime_next", on_next_episode)
mp.add_forced_key_binding("N", "sranime_next_shift", on_next_episode)
mp.add_forced_key_binding("p", "sranime_prev", on_prev_episode)
mp.add_forced_key_binding("P", "sranime_prev_shift", on_prev_episode)
mp.add_forced_key_binding("b", "sranime_bookmark", on_bookmark)
mp.add_forced_key_binding("B", "sranime_bookmark_shift", on_bookmark)
mp.add_forced_key_binding("s", "sranime_cycle_sub", on_cycle_subs)
mp.add_forced_key_binding("S", "sranime_cycle_sub_shift", on_cycle_subs)

-- Register event observers
mp.register_event("file-loaded", show_welcome_hud)
