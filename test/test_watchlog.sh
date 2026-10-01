#!/bin/sh
# Unit tests for lib/sranime-cli/watchlog.sh

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE_DIR/test/test_utils.sh"

# Set up isolated temp state dir for tests
TEST_STATE_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'sranime_test')"
export SRANIME_CLI_HIST_DIR="$TEST_STATE_DIR"

. "$BASE_DIR/lib/sranime-cli/watchlog.sh"

printf "\033[1;36mRunning watchlog module tests...\033[0m\n"

# Test 1: Empty watch log view
output=$(watchlog_show)
assert_contains "empty log displays guidance" "$output" "Watch log is empty"

# Test 2: Append WATCH event
watchlog_append "WATCH" "1" "frieren-18542" "Frieren: Beyond Journey's End" "hianime"
watchlog_append "WATCH" "2" "frieren-18542" "Frieren: Beyond Journey's End" "hianime"
watchlog_append "DOWNLOAD" "1" "one-piece-100" "One Piece" "allanime"

# Test 3: Check log file entry count
count=$(grep -c . "$TEST_STATE_DIR/watch.log")
assert_eq "watch.log has 3 entries" "3" "$count"

# Test 4: Show output contains titles
show_out=$(watchlog_show)
assert_contains "show output includes Frieren" "$show_out" "Frieren: Beyond Journey's End"
assert_contains "show output includes One Piece" "$show_out" "One Piece"
assert_contains "show output includes WATCH" "$show_out" "WATCH"
assert_contains "show output includes DOWNLOAD" "$show_out" "DOWNLOAD"

# Test 5: Filter show output
frieren_out=$(watchlog_show "frieren")
assert_contains "filter includes matching anime" "$frieren_out" "Frieren"
assert_contains "filter shows match summary" "$frieren_out" "Showing 2 entries matching"

# Test 5b: Date range filter
range_out=$(watchlog_show "2020-01-01..2030-12-31")
assert_contains "date range filter matches entries" "$range_out" "Frieren"

# Test 6: Stats output
stats_out=$(watchlog_stats)
assert_contains "stats shows 2 watched" "$stats_out" "Episodes Watched   : "
assert_contains "stats shows 1 downloaded" "$stats_out" "Episodes Downloaded: "
assert_contains "stats shows 2 unique series" "$stats_out" "Unique Series      : "
assert_contains "stats shows estimated watch time" "$stats_out" "Est. Watch Time"
assert_contains "stats shows viewing streaks" "$stats_out" "Viewing Streaks"

# Test 7: Export CSV
csv_out=$(watchlog_export csv)
assert_contains "csv export header" "$csv_out" "timestamp,action,episode,anime_id,anime_title,provider"
assert_contains "csv export row" "$csv_out" "Frieren: Beyond Journey's End"

# Test 8: Export JSON
json_out=$(watchlog_export json)
assert_contains "json export structure" "$json_out" '"anime_title": "One Piece"'

# Test 9: Clear log
watchlog_clear
if [ -s "$TEST_STATE_DIR/watch.log" ]; then
    empty_status="not_empty"
else
    empty_status="empty"
fi
assert_eq "watch.log is empty after clear" "empty" "$empty_status"

# Cleanup
rm -rf "$TEST_STATE_DIR"

print_test_summary
