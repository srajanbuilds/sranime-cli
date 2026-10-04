#!/bin/sh
# Unit tests for lib/sranime-cli/scrobbler.sh
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE_DIR/test/test_utils.sh"

# Set up isolated temp config dir
TEST_CONFIG_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'sranime_scrobbler_test')"
export XDG_CONFIG_HOME="$TEST_CONFIG_DIR"
export SRANIME_LIB_DIR="$BASE_DIR/lib/sranime-cli"

. "$BASE_DIR/lib/sranime-cli/scrobbler.sh"

printf "\033[1;36mRunning scrobbler module tests...\033[0m\n"

# Test 1: Empty scrobbler status
status_empty=$(scrobble_status)
assert_contains "Unauthenticated AniList shows Not Connected" "$status_empty" "AniList"
assert_contains "Unauthenticated shows Not Connected text" "$status_empty" "Not Connected"

# Test 2: scrobble_verify_anilist fails with empty token
if scrobble_verify_anilist ""; then
    verify_res="ok"
else
    verify_res="fail"
fi
assert_eq "verify with empty token fails" "fail" "$verify_res"

# Test 3: Mock token save and verify persistence
_anilist_token="test_mock_token_12345"
_anilist_uid="998877"
_anilist_uname="test_otaku_user"
_save_auth

auth_file="$TEST_CONFIG_DIR/sranime-cli/auth.json"
assert_eq "auth.json file exists" "1" "$([ -f "$auth_file" ] && echo 1 || echo 0)"

# Test 4: Verify credentials load
_anilist_token=""
_anilist_uid=""
_anilist_uname=""
_load_auth

assert_eq "Loaded token matches" "test_mock_token_12345" "$_anilist_token"
assert_eq "Loaded user ID matches" "998877" "$_anilist_uid"
assert_eq "Loaded username matches" "test_otaku_user" "$_anilist_uname"

# Test 5: Status displays authenticated user
status_auth=$(scrobble_status)
assert_contains "Status shows Connected" "$status_auth" "Connected"
assert_contains "Status shows username" "$status_auth" "test_otaku_user"
assert_contains "Status shows user ID" "$status_auth" "998877"

# Test 6: CLI flags integration
cli_status=$("$BASE_DIR/sranime-cli" --scrobble-status 2>/dev/null)
assert_contains "CLI --scrobble-status outputs connected user" "$cli_status" "test_otaku_user"

# Test 7: Logout
scrobble_logout "anilist"
status_after_logout=$(scrobble_status)
assert_contains "After logout shows Not Connected" "$status_after_logout" "Not Connected"

# Cleanup
rm -rf "$TEST_CONFIG_DIR" 2>/dev/null || true

print_test_summary
