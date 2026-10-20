#!/bin/sh
# test/test_offline.sh - Unit tests for Offline Mode & Local Vault Player

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$REPO_ROOT/lib/sranime-cli"

. "$SCRIPT_DIR/test_utils.sh"
. "$LIB_DIR/offline.sh"

printf "Running Offline Mode & Local Vault module tests...\n"

# Test 1: Function definitions
assert_eq "offline_scan_library is defined" "0" "$(command -v offline_scan_library >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "offline_list_shows is defined" "0" "$(command -v offline_list_shows >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "offline_list_episodes is defined" "0" "$(command -v offline_list_episodes >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "offline_play_file is defined" "0" "$(command -v offline_play_file >/dev/null 2>&1 && echo 0 || echo 1)"

# Test 2: Create mock vault structure and scan
_vault=$(mktemp -d 2>/dev/null || echo "/tmp/test_offline_vault")
mkdir -p "$_vault/Frieren/Season 01"
mkdir -p "$_vault/Dungeon Meshi"

# Dummy files
echo "dummy" > "$_vault/Frieren/Season 01/Frieren - S01E14 - [1080p].mp4"
echo "dummy" > "$_vault/Frieren/Season 01/Frieren - S01E14 - [1080p].vtt"
echo "dummy" > "$_vault/Frieren/Season 01/Frieren - S01E15 - [1080p].mp4"
echo "dummy" > "$_vault/Dungeon Meshi/Dungeon Meshi - S01E05 - [720p].mkv"

_scan=$(offline_scan_library "$_vault")
assert_contains "Scan includes Frieren Ep 14" "$_scan" "Frieren - S01E14"
assert_contains "Scan includes Frieren Ep 15" "$_scan" "Frieren - S01E15"
assert_contains "Scan includes Dungeon Meshi" "$_scan" "Dungeon Meshi"

# Test 3: List unique shows
_shows=$(offline_list_shows "$_vault")
assert_contains "Shows list includes Frieren" "$_shows" "Frieren"
assert_contains "Shows list includes Dungeon Meshi" "$_shows" "Dungeon Meshi"

# Test 4: List episodes for show
_frieren_eps=$(offline_list_episodes "$_vault" "Frieren")
assert_contains "Episode list includes Ep 14" "$_frieren_eps" "Episode 14"
assert_contains "Episode list includes Ep 15" "$_frieren_eps" "Episode 15"

# Test 5: Play offline file with debug player
SRANIME_CLI_PLAYER="debug"
_ep14_file="$_vault/Frieren/Season 01/Frieren - S01E14 - [1080p].mp4"
_debug_play=$(offline_play_file "$_ep14_file" "Frieren" "14")
assert_contains "Debug offline play outputs file" "$_debug_play" "file=$_ep14_file"
assert_contains "Debug offline play attaches sidecar subtitle" "$_debug_play" "sub=$_vault/Frieren/Season 01/Frieren - S01E14 - [1080p].vtt"
assert_contains "Debug offline play has episode number" "$_debug_play" "ep=14"

rm -rf "$_vault" 2>/dev/null || true
print_test_summary
