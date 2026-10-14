#!/bin/sh
# Unit tests for lib/sranime-cli/queue.sh
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE_DIR/test/test_utils.sh"

TEST_Q_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'sranime_queue_test')"
export SRANIME_CLI_STATE_DIR="$TEST_Q_DIR"
export SRANIME_LIB_DIR="$BASE_DIR/lib/sranime-cli"

. "$BASE_DIR/lib/sranime-cli/queue.sh"

printf "\033[1;36mRunning download queue module tests...\033[0m\n"

# Test 1: queue_init creates queue.tsv with header
queue_init
assert_eq "queue.tsv exists" "1" "$([ -f "$_queue_file" ] && echo 1 || echo 0)"
assert_contains "queue.tsv has header" "$(head -n 1 "$_queue_file")" "# ID"

# Test 2: queue_add enqueues items
qid1=$(queue_add "Frieren" "14" "1080p" "hianime" "/tmp/anime")
assert_contains "QID starts with Q" "$qid1" "Q"
assert_contains "Queue file has Frieren" "$(cat "$_queue_file")" "Frieren"
assert_contains "Queue file has status QUEUED" "$(cat "$_queue_file")" "QUEUED"

qid2=$(queue_add "Dungeon Meshi" "5" "720p" "allanime" "/tmp/anime")
assert_contains "Queue file has second item" "$(cat "$_queue_file")" "Dungeon Meshi"

# Test 3: queue_list displays queue
q_display=$(queue_list)
assert_contains "Queue list shows header" "$q_display" "Download Queue"
assert_contains "Queue list shows Frieren" "$q_display" "Frieren"
assert_contains "Queue list shows Dungeon Meshi" "$q_display" "Dungeon Meshi"

# Test 4: queue_set_status updates item status
queue_set_status "$qid1" "DOWNLOADING"
assert_contains "Queue file shows DOWNLOADING status" "$(cat "$_queue_file")" "DOWNLOADING"

queue_set_status "$qid1" "DONE"
assert_contains "Queue file shows DONE status" "$(cat "$_queue_file")" "DONE"

# Test 5: queue_get_next returns next QUEUED item
next_item=$(queue_get_next)
assert_contains "Next item is Dungeon Meshi" "$next_item" "Dungeon Meshi"
assert_contains "Next item has QID" "$next_item" "$qid2"

# Test 6: Pause and resume queue
assert_eq "Queue is initially unpaused" "0" "$([ -f "$_queue_paused_file" ] && echo 1 || echo 0)"
queue_pause
assert_eq "Queue pause creates paused file" "1" "$([ -f "$_queue_paused_file" ] && echo 1 || echo 0)"
assert_eq "queue_get_next returns nothing when paused" "1" "$([ -z "$(queue_get_next)" ] && echo 1 || echo 0)"
queue_resume
assert_eq "Queue resume removes paused file" "0" "$([ -f "$_queue_paused_file" ] && echo 1 || echo 0)"

# Test 7: queue_clear completed removes DONE items but preserves QUEUED
queue_clear "completed" >/dev/null 2>&1
assert_eq "Cleared completed does not contain Frieren" "0" "$(grep -q "Frieren" "$_queue_file" && echo 1 || echo 0)"
assert_eq "Cleared completed retains Dungeon Meshi" "1" "$(grep -q "Dungeon Meshi" "$_queue_file" && echo 1 || echo 0)"

# Test 8: queue_clear all purges queue
queue_clear "all" >/dev/null 2>&1
assert_eq "Queue is empty after all clear" "0" "$([ "$(grep -v '^#' "$_queue_file" | wc -l)" -gt 0 ] && echo 1 || echo 0)"

# Cleanup
rm -rf "$TEST_Q_DIR" 2>/dev/null || true

print_test_summary
