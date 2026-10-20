#!/bin/sh
# test/test_colortheme.sh - Unit tests for terminal color theme presets subsystem

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$REPO_ROOT/lib/sranime-cli"

. "$SCRIPT_DIR/test_utils.sh"
. "$LIB_DIR/theme_colors.sh"

printf "Running terminal color theme presets module tests...\n"

# Test 1: Valid themes list
_list=$(theme_colors_list)
assert_contains "Themes list contains catppuccin" "$_list" "catppuccin"
assert_contains "Themes list contains dracula" "$_list" "dracula"
assert_contains "Themes list contains nord" "$_list" "nord"
assert_contains "Themes list contains gruvbox" "$_list" "gruvbox"
assert_contains "Themes list contains tokyo-night" "$_list" "tokyo-night"
assert_contains "Themes list contains cyberpunk" "$_list" "cyberpunk"

# Test 2: Theme validation
assert_exit_code "Validation succeeds for catppuccin" 0 "theme_colors_valid 'catppuccin'"
assert_exit_code "Validation succeeds for dracula" 0 "theme_colors_valid 'dracula'"
assert_exit_code "Validation fails for nonexistent theme" 1 "theme_colors_valid 'fake_theme'"

# Test 3: fzf options generation
_cat_fzf=$(theme_colors_fzf_opts "catppuccin")
assert_contains "Catppuccin fzf options include bg color" "$_cat_fzf" "bg:#1e1e2e"
assert_contains "Catppuccin fzf options include border color" "$_cat_fzf" "border:#b4befe"

_drac_fzf=$(theme_colors_fzf_opts "dracula")
assert_contains "Dracula fzf options include bg color" "$_drac_fzf" "bg:#282a36"

# Test 4: ANSI variable setting
theme_colors_set "catppuccin"
assert_contains "Catppuccin border is set" "$_tc_border" "180;190;254m"

theme_colors_set "default"
assert_contains "Default border fallback" "$_tc_border" "1;36m"

print_test_summary
