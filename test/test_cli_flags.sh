#!/bin/sh
# Tests for CLI flag parsing and basic behaviors
set -e
. "$(dirname "$0")/test_utils.sh"

SRANIME_CLI="./sranime-cli"

printf "\n\033[1;36mCLI Flag Tests\033[0m\n\n"

_version=$($SRANIME_CLI -V 2>/dev/null)
assert_contains "Version outputs a version string" "$_version" "5."

_version_long=$($SRANIME_CLI --version 2>/dev/null)
assert_eq "Short and long version flags match" "$_version" "$_version_long"

_help=$($SRANIME_CLI -h 2>/dev/null)
assert_contains "Help contains Usage section" "$_help" "Usage"
assert_contains "Help contains --continue flag" "$_help" "--continue"
assert_contains "Help contains --download flag" "$_help" "--download"
assert_contains "Help contains --doctor flag" "$_help" "--doctor"
assert_contains "Help contains --edit-config flag" "$_help" "--edit-config"
assert_contains "Help contains --watch-log flag" "$_help" "--watch-log"
assert_contains "Help contains --watch-stats flag" "$_help" "--watch-stats"
assert_contains "Help contains --login flag" "$_help" "--login"
assert_contains "Help contains --scrobble-status flag" "$_help" "--scrobble-status"
assert_contains "Help contains --logout flag" "$_help" "--logout"
assert_contains "Help contains --sync flag" "$_help" "--sync"
assert_contains "Help contains --sync-list flag" "$_help" "--sync-list"
assert_contains "Help contains --no-scrobble flag" "$_help" "--no-scrobble"
assert_contains "Help contains --discord flag" "$_help" "--discord"
assert_contains "Help contains --no-discord flag" "$_help" "--no-discord"
assert_contains "Help contains --room flag" "$_help" "--room"
assert_contains "Help contains --download-dir flag" "$_help" "--download-dir"
assert_contains "Help contains --autoplay flag" "$_help" "--autoplay"
assert_contains "Help contains --resume flag" "$_help" "--resume"
assert_contains "Help contains --start-time flag" "$_help" "--start-time"
assert_contains "Help contains --show-checkpoints flag" "$_help" "--show-checkpoints"
assert_contains "Help contains --seasonal flag" "$_help" "--seasonal"
assert_contains "Help contains --trending flag" "$_help" "--trending"
assert_contains "Help contains --calendar flag" "$_help" "--calendar"
assert_contains "Help contains --similar flag" "$_help" "--similar"
assert_contains "Help contains --export-mal flag" "$_help" "--export-mal"
assert_contains "Help contains --import-mal flag" "$_help" "--import-mal"
assert_contains "Help contains --nfo flag" "$_help" "--nfo"
assert_contains "Help contains --save-subs flag" "$_help" "--save-subs"
assert_contains "Help contains --queue flag" "$_help" "--queue"
assert_contains "Help contains --queue-status flag" "$_help" "--queue-status"
assert_contains "Help contains --queue-start flag" "$_help" "--queue-start"
assert_contains "Help contains --queue-pause flag" "$_help" "--queue-pause"
assert_contains "Help contains --queue-resume flag" "$_help" "--queue-resume"
assert_contains "Help contains --queue-clear flag" "$_help" "--queue-clear"

_config=$($SRANIME_CLI --dump-config 2>/dev/null)
assert_contains "Dump config shows active_provider" "$_config" "active_provider:"
assert_contains "Dump config shows mode" "$_config" "mode:"
assert_contains "Dump config shows quality" "$_config" "quality:"
assert_contains "Dump config shows player" "$_config" "player_function:"
assert_contains "Dump config shows enable_preview" "$_config" "enable_preview:"

_hist=$($SRANIME_CLI --show-history 2>/dev/null)
assert_contains "Show history produces output" "$_hist" "history"

_wlog=$($SRANIME_CLI -W 2>/dev/null)
if printf "%s" "$_wlog" | grep -qiE "(Watch log|Anime Title)"; then
    assert_eq "Watch log outputs status" "1" "1"
else
    assert_contains "Watch log outputs status" "$_wlog" "Watch log"
fi

_wstats=$($SRANIME_CLI --watch-stats 2>/dev/null)
if printf "%s" "$_wstats" | grep -qiE "(watch history|Statistics)"; then
    assert_eq "Watch stats outputs status" "1" "1"
else
    assert_contains "Watch stats outputs status" "$_wstats" "watch history"
fi

_provs=$($SRANIME_CLI --list-providers 2>/dev/null)
assert_contains "List providers outputs hianime" "$_provs" "hianime"
assert_contains "List providers outputs allanime" "$_provs" "allanime"
assert_contains "List providers outputs gogo" "$_provs" "gogo"

_scrobble=$($SRANIME_CLI --scrobble-status 2>/dev/null)
assert_contains "Scrobble status produces output" "$_scrobble" "AniList"

$SRANIME_CLI --doctor >/dev/null 2>&1 || true

print_test_summary