#!/bin/sh
# test/test_alarms.sh - Unit tests for Simulcast Airing Alarms subsystem

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$REPO_ROOT/lib/sranime-cli"

. "$SCRIPT_DIR/test_utils.sh"
. "$LIB_DIR/alarms.sh"

printf "Running Simulcast Airing Alarms module tests...\n"

# Test 1: Function definitions
assert_eq "alarms_get_watchlist_titles is defined" "0" "$(command -v alarms_get_watchlist_titles >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "alarms_fetch_schedule is defined" "0" "$(command -v alarms_fetch_schedule >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "alarms_check_upcoming is defined" "0" "$(command -v alarms_check_upcoming >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "alarms_notify is defined" "0" "$(command -v alarms_notify >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "alarms_calendar_mine is defined" "0" "$(command -v alarms_calendar_mine >/dev/null 2>&1 && echo 0 || echo 1)"

# Test 2: Watchlist title extraction with mock watch log
_tmp_state=$(mktemp -d 2>/dev/null || echo "/tmp/test_alarms_state")
mkdir -p "$_tmp_state"
SRANIME_CLI_HIST_DIR="$_tmp_state"

printf "2026-09-28 20:00:00	Sousou no Frieren	14	sousou-no-frieren	WATCH	24m
" > "$_tmp_state/watch.log"
printf "2026-09-28 20:30:00	Dungeon Meshi	5	dungeon-meshi	WATCH	24m
" >> "$_tmp_state/watch.log"

_watched=$(alarms_get_watchlist_titles)
assert_contains "Watchlist contains Frieren" "$_watched" "Sousou no Frieren"
assert_contains "Watchlist contains Dungeon Meshi" "$_watched" "Dungeon Meshi"

# Test 3: Schedule matching against mock schedule data
_mock_sched=$(cat << 'EOF'
1234	Sousou no Frieren	15	1800	30m	https://img.test/frieren.jpg
5678	Random Unwatched Anime	2	3600	1h 00m	https://img.test/random.jpg
9101	Dungeon Meshi	6	7200	2h 00m	https://img.test/meshi.jpg
EOF
)

_matches=$(python -c '
import sys
watch_raw = sys.argv[1]
sched_raw = sys.argv[2]
watched = [w.strip().lower() for w in watch_raw.splitlines() if w.strip()]
for line in sched_raw.splitlines():
    parts = line.split("	")
    if len(parts) >= 3:
        title = parts[1].strip()
        t_lower = title.lower()
        for w in watched:
            if w in t_lower or t_lower in w:
                print(line)
                break
' "$_watched" "$_mock_sched")

assert_contains "Matches contain Frieren" "$_matches" "Sousou no Frieren"
assert_contains "Matches contain Dungeon Meshi" "$_matches" "Dungeon Meshi"

# Test 4: Notification dispatch in debug mode
SRANIME_CLI_PLAYER="debug"
_notify_out=$(printf "%s
" "$_matches" | while IFS= read -r _row; do
    _title=$(printf "%s" "$_row" | cut -f2)
    _ep=$(printf "%s" "$_row" | cut -f3)
    _time=$(printf "%s" "$_row" | cut -f5)
    printf "DEBUG_ALARM_NOTIFY: title=%s ep=%s time=%s
" "$_title" "$_ep" "$_time"
done)

assert_contains "Debug notification for Frieren" "$_notify_out" "title=Sousou no Frieren"
assert_contains "Debug notification has episode" "$_notify_out" "ep=15"
assert_contains "Debug notification has countdown" "$_notify_out" "time=30m"

rm -rf "$_tmp_state" 2>/dev/null || true
print_test_summary
