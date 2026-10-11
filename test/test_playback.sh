#!/bin/sh
# Unit tests for lib/sranime-cli/playback.sh (timestamp precision & checkpoints)
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE_DIR/test/test_utils.sh"

export SRANIME_LIB_DIR="$BASE_DIR/lib/sranime-cli"
export SRANIME_CLI_STATE_DIR="$(mktemp -d 2>/dev/null || echo "/tmp/sranime_test_pb_$$")"
mkdir -p "$SRANIME_CLI_STATE_DIR"

. "$BASE_DIR/lib/sranime-cli/playback.sh"

printf "\033[1;36mRunning playback and checkpoint module tests...\033[0m\n"

# Test 1: playback_format_time
assert_eq "playback_format_time 0s" "00:00" "$(playback_format_time 0)"
assert_eq "playback_format_time 75s" "01:15" "$(playback_format_time 75)"
assert_eq "playback_format_time 1122s" "18:42" "$(playback_format_time 1122)"
assert_eq "playback_format_time 3665s" "01:01:05" "$(playback_format_time 3665)"

# Test 2: playback_parse_time
assert_eq "playback_parse_time MM:SS" "1122" "$(playback_parse_time "18:42")"
assert_eq "playback_parse_time HH:MM:SS" "3665" "$(playback_parse_time "01:01:05")"
assert_eq "playback_parse_time raw seconds" "500" "$(playback_parse_time "500")"

# Test 3: playback_save_checkpoint
playback_save_checkpoint "Sousou no Frieren" "14" 1122 82
if [ -f "$_checkpoint_file" ]; then
    assert_eq "checkpoints.tsv exists" "1" "1"
else
    assert_eq "checkpoints.tsv exists" "1" "0"
fi

# Test 4: playback_get_checkpoint
cp_data=$(playback_get_checkpoint "Sousou no Frieren")
assert_contains "Checkpoint contains episode 14" "$cp_data" "14"
assert_contains "Checkpoint contains seconds 1122" "$cp_data" "1122"
assert_contains "Checkpoint contains formatted 18:42" "$cp_data" "18:42"
assert_contains "Checkpoint contains 82 percent" "$cp_data" "82"

# Test 5: playback_get_checkpoint with matching episode
cp_match=$(playback_get_checkpoint "Sousou no Frieren" "14")
assert_contains "Matching episode returns checkpoint" "$cp_match" "18:42"

# Test 6: playback_get_checkpoint with different episode returns 1
if playback_get_checkpoint "Sousou no Frieren" "99" >/dev/null 2>&1; then
    assert_eq "Non-matching episode returns failure" "0" "1"
else
    assert_eq "Non-matching episode returns failure" "1" "1"
fi

# Test 7: playback_clear_checkpoint
playback_clear_checkpoint "Sousou no Frieren"
cp_cleared=$(playback_get_checkpoint "Sousou no Frieren" || true)
assert_eq "Cleared checkpoint returns empty" "" "$cp_cleared"

# Test 8: playback_prepare_observer
scrob_f="$SRANIME_CLI_STATE_DIR/test_scrob"
pos_f="$SRANIME_CLI_STATE_DIR/test_pos"
lua_f=$(playback_prepare_observer "$scrob_f" "$pos_f")
if [ -f "$lua_f" ]; then
    assert_eq "Unified Lua observer script created" "1" "1"
else
    assert_eq "Unified Lua observer script created" "1" "0"
fi
lua_content=$(cat "$lua_f")
assert_contains "Lua script contains shutdown hook" "$lua_content" "shutdown"
assert_contains "Lua script contains time-pos observer" "$lua_content" "time-pos"
assert_contains "Lua script contains percent-pos observer" "$lua_content" "percent-pos"

rm -rf "$SRANIME_CLI_STATE_DIR"
print_test_summary
