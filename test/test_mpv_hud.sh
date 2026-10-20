#!/bin/sh
# test/test_mpv_hud.sh - Unit tests for MPV Lua HUD and hotkeys subsystem

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$REPO_ROOT/lib/sranime-cli"

. "$SCRIPT_DIR/test_utils.sh"

printf "Running MPV HUD & Binge Navigation module tests...\n"

_hud_file="$LIB_DIR/mpv_hud.lua"

# Test 1: mpv_hud.lua exists
assert_eq "mpv_hud.lua exists" "0" "$([ -f "$_hud_file" ] && echo 0 || echo 1)"

# Test 2: Contains required hotkey bindings
_content=$(cat "$_hud_file" 2>/dev/null)
assert_contains "Binds next key n" "$_content" '"n", "sranime_next"'
assert_contains "Binds next key N" "$_content" '"N", "sranime_next_shift"'
assert_contains "Binds prev key p" "$_content" '"p", "sranime_prev"'
assert_contains "Binds prev key P" "$_content" '"P", "sranime_prev_shift"'
assert_contains "Binds bookmark key b" "$_content" '"b", "sranime_bookmark"'
assert_contains "Binds cycle sub key s" "$_content" '"s", "sranime_cycle_sub"'

# Test 3: Exit code constants
assert_contains "Defines CODE_NEXT_EPISODE 101" "$_content" "CODE_NEXT_EPISODE = 101"
assert_contains "Defines CODE_PREV_EPISODE 102" "$_content" "CODE_PREV_EPISODE = 102"

# Test 4: OSD overlay functions
assert_contains "Contains welcome HUD function" "$_content" "show_welcome_hud"
assert_contains "Registers file-loaded event" "$_content" 'mp.register_event("file-loaded", show_welcome_hud)'

print_test_summary
