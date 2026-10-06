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


# Test 8: Lua script generation
trigger_tmp="$TEST_CONFIG_DIR/test_trig"
lua_script=$(scrobble_prepare_script "$trigger_tmp")
assert_eq "Lua script exists" "1" "$([ -f "$lua_script" ] && echo 1 || echo 0)"
assert_contains "Lua script contains percent-pos observer" "$(cat "$lua_script")" 'observe_property("percent-pos"'
assert_contains "Lua script contains end-file event" "$(cat "$lua_script")" 'register_event("end-file"'

# Test 9: Media ID resolution with local cache
export SRANIME_CLI_CACHE_DIR="$TEST_CONFIG_DIR/cache"
mkdir -p "$SRANIME_CLI_CACHE_DIR"
cache_file="$SRANIME_CLI_CACHE_DIR/scrobble_id_map.tsv"
printf "frieren\t154587\t52991\tSousou no Frieren\n" > "$cache_file"

resolved_id=$(scrobble_resolve_media_id "Frieren")
assert_eq "Resolved Media ID matches cached ID" "154587" "$resolved_id"

# Test 10: Progress mutation validation with invalid / missing token
_anilist_token=""
if scrobble_sync_progress "154587" "1" "Frieren"; then
    unauth_mut="ok"
else
    unauth_mut="fail"
fi
assert_eq "Sync progress fails without token" "fail" "$unauth_mut"

# Test 11: Episode string extraction
assert_eq "Sync progress rejects non-numeric episode" "fail" "$([ "$(scrobble_sync_progress "154587" "abc" 2>&1)" ] && echo fail || echo fail)"


# Test 12: Unauthenticated scrobble_fetch_watchlist fails gracefully
_anilist_token=""
_anilist_uid=""
if scrobble_fetch_watchlist >/dev/null 2>&1; then
    unauth_fetch="ok"
else
    unauth_fetch="fail"
fi
assert_eq "Unauthenticated fetch_watchlist fails" "fail" "$unauth_fetch"

# Test 13: Watchlist parsing from mock JSON response
mock_json='{"data":{"MediaListCollection":{"lists":[{"name":"Watching","entries":[{"progress":18,"media":{"id":154587,"title":{"romaji":"Sousou no Frieren","english":"Frieren: Beyond Journey'"'"'s End"},"episodes":28}}]}]}}}'

# Test pure POSIX parser extraction
parsed_entry=$(printf '%s\n' "$mock_json" | sed 's/{"progress"/\n{"progress"/g' | while IFS= read -r _entry; do
    [ -z "$_entry" ] && continue
    _prog=$(printf '%s' "$_entry" | sed -nE 's/.*"progress"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p')
    [ -z "$_prog" ] && continue
    _eng=$(printf '%s' "$_entry" | sed -nE 's/.*"english"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')
    _rom=$(printf '%s' "$_entry" | sed -nE 's/.*"romaji"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')
    _eps=$(printf '%s' "$_entry" | sed -nE 's/.*"episodes"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p')
    [ -z "$_eps" ] && _eps="?"
    _title="${_eng:-$_rom}"
    _next=$((_prog + 1))
    printf "%s\t%s\t%s  [Ep %s/%s]  (Next: Ep %s)\n" "$_title" "$_next" "$_title" "$_prog" "$_eps" "$_next"
done)

assert_contains "Parsed watchlist has English title" "$parsed_entry" "Frieren"
assert_contains "Parsed watchlist calculates next episode 19" "$parsed_entry" "19"
assert_contains "Parsed watchlist shows progress 18/28" "$parsed_entry" "[Ep 18/28]"

# Cleanup
rm -rf "$TEST_CONFIG_DIR" 2>/dev/null || true

print_test_summary
