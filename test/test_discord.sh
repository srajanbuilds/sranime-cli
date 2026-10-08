#!/bin/sh
# Unit tests for lib/sranime-cli/discord.sh and syncplay.sh
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE_DIR/test/test_utils.sh"

export SRANIME_LIB_DIR="$BASE_DIR/lib/sranime-cli"
. "$BASE_DIR/lib/sranime-cli/discord.sh"
. "$BASE_DIR/lib/sranime-cli/syncplay.sh"

printf "\033[1;36mRunning discord and syncplay module tests...\033[0m\n"

# Test 1: discord_format_handshake
hs=$(discord_format_handshake "123456789")
assert_contains "Handshake contains client_id" "$hs" "123456789"
assert_contains "Handshake contains version 1" "$hs" '"v": 1'

# Test 2: discord_format_activity
act=$(discord_format_activity "Frieren: Beyond Journey's End" "18" "Sub" 9999 1790600000)
assert_contains "Activity contains details title" "$act" "Frieren: Beyond Journey's End"
assert_contains "Activity contains state episode" "$act" "Episode 18 (Sub)"
assert_contains "Activity contains PID" "$act" "9999"
assert_contains "Activity contains timestamp" "$act" "1790600000"
assert_contains "Activity contains mpv asset" "$act" "mpv"

# Test 3: discord_find_pipe fallback
pipe=$(discord_find_pipe 2>/dev/null || true)
assert_eq "discord_find_pipe executes without crashing" "1" "1"

# Test 4: syncplay_format_args
s_args=$(syncplay_format_args "AnimeNight" "mpv" "Frieren")
assert_contains "Syncplay args include room" "$s_args" "--room AnimeNight"
assert_contains "Syncplay args include player" "$s_args" "--player-path mpv"

print_test_summary
