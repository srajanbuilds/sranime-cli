#!/bin/sh
# test/test_tui.sh - Unit tests for Anime Bento TUI Dashboard subsystem

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$REPO_ROOT/lib/sranime-cli"

. "$SCRIPT_DIR/test_utils.sh"
. "$LIB_DIR/tui.sh"

printf "Running Anime Bento TUI Dashboard module tests...\n"

# Test 1: Function definitions
assert_eq "tui_render_dashboard is defined" "0" "$(command -v tui_render_dashboard >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "tui_run is defined" "0" "$(command -v tui_run >/dev/null 2>&1 && echo 0 || echo 1)"

# Test 2: Headless render in debug mode
SRANIME_CLI_PLAYER="debug"
_dash_output=$(tui_render_dashboard)

assert_contains "Dashboard contains Bento title" "$_dash_output" "Anime Bento Dashboard"
assert_contains "Dashboard contains Streak indicator" "$_dash_output" "Streak:"
assert_contains "Dashboard contains Watched counter" "$_dash_output" "Watched:"
assert_contains "Dashboard contains Provider indicator" "$_dash_output" "Provider:"
assert_contains "Dashboard contains Checkpoints section" "$_dash_output" "RESUME CHECKPOINTS"
assert_contains "Dashboard contains Simulcast Radar section" "$_dash_output" "SIMULCAST AIRING RADAR"
assert_contains "Dashboard contains System Health section" "$_dash_output" "SYSTEM HEALTH"
assert_contains "Dashboard contains Command Bar hotkeys" "$_dash_output" "Quit"
assert_contains "Dashboard command bar has Manga key" "$_dash_output" "Manga Reader"
assert_contains "Dashboard command bar has Themes key" "$_dash_output" "Themes Jukebox"

# Test 3: tui_run executes cleanly in debug mode
assert_exit_code "tui_run returns 0 in debug mode" 0 "tui_run"

print_test_summary
