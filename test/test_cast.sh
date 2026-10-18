#!/bin/sh
# test/test_cast.sh - Unit tests for Smart TV & Chromecast casting subsystem

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$REPO_ROOT/lib/sranime-cli"

. "$SCRIPT_DIR/test_utils.sh"
. "$LIB_DIR/cast.sh"

printf "Running Smart TV and Chromecast casting module tests...\n"

# Test 1: Empty URL rejection
assert_exit_code "cast_stream rejects empty url" 1 "cast_stream '' 'Living Room TV'"

# Test 2: Invalid control action
assert_exit_code "cast_control rejects invalid action" 1 "cast_control 'invalid_action'"

# Test 3: Function definitions
assert_eq "cast_is_available is defined" "0" "$(command -v cast_is_available >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "cast_scan_devices is defined" "0" "$(command -v cast_scan_devices >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "cast_stream is defined" "0" "$(command -v cast_stream >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "cast_control is defined" "0" "$(command -v cast_control >/dev/null 2>&1 && echo 0 || echo 1)"

print_test_summary
