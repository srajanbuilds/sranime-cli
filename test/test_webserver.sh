#!/bin/sh
# test/test_webserver.sh - Unit tests for web companion microserver

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$REPO_ROOT/lib/sranime-cli"

. "$SCRIPT_DIR/test_utils.sh"
. "$LIB_DIR/webserver.sh"

printf "Running web companion module tests...\n"

# Test 1: Functions defined
assert_eq "webserver_is_running is defined" "0" "$(command -v webserver_is_running >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "webserver_status is defined" "0" "$(command -v webserver_status >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "webserver_start is defined" "0" "$(command -v webserver_start >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "webserver_stop is defined" "0" "$(command -v webserver_stop >/dev/null 2>&1 && echo 0 || echo 1)"

# Test 2: Status reporting when stopped
webserver_pid_file="/tmp/sranime_test_nonexistent_pid_$$"
_status_out=$(webserver_status 2>&1 || true)
assert_contains "webserver_status reports stopped when no process running" "$_status_out" "stopped"

# Test 3: Stop when not running
_stop_out=$(webserver_stop 2>&1 || true)
assert_contains "webserver_stop reports not running safely" "$_stop_out" "not running"

print_test_summary
