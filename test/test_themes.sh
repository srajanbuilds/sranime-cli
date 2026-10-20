#!/bin/sh
# test/test_themes.sh - Unit tests for AnimeThemes.moe Theme Jukebox subsystem

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$REPO_ROOT/lib/sranime-cli"

. "$SCRIPT_DIR/test_utils.sh"
. "$LIB_DIR/themes.sh"

printf "Running AnimeThemes jukebox module tests...\n"

# Test 1: Function definitions
assert_eq "themes_search is defined" "0" "$(command -v themes_search >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "themes_extract_tracks is defined" "0" "$(command -v themes_extract_tracks >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "themes_play_track is defined" "0" "$(command -v themes_play_track >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "themes_download_track is defined" "0" "$(command -v themes_download_track >/dev/null 2>&1 && echo 0 || echo 1)"

# Test 2: Search rejects empty query
assert_exit_code "themes_search rejects empty query" 1 "themes_search ''"

# Test 3: Mock JSON parsing of anime list
_sample_json='{"anime":[{"id":4771,"name":"Sousou no Frieren","slug":"sousou_no_frieren","year":2023,"animethemes":[{"id":1,"slug":"OP1","type":"OP","song":{"title":"Yuusha","artists":[{"name":"YOASOBI"}]},"animethemeentries":[{"videos":[{"link":"https://v.animethemes.moe/SousouNoFrieren-OP1.webm","resolution":1080,"tags":"NC"}]}]},{"id":2,"slug":"ED1","type":"ED","song":{"title":"Anytime Anywhere","artists":[{"name":"milet"}]},"animethemeentries":[{"videos":[{"link":"https://v.animethemes.moe/SousouNoFrieren-ED1.webm","resolution":1080,"tags":"NC"}]}]}]}]}'

_parsed_list=$(themes_parse_anime_list "$_sample_json")
assert_contains "Parsed list contains anime title" "$_parsed_list" "Sousou no Frieren"
assert_contains "Parsed list contains year" "$_parsed_list" "2023"
assert_contains "Parsed list contains slug" "$_parsed_list" "sousou_no_frieren"

# Test 4: Track extraction (all, op, ed)
_tracks_all=$(themes_extract_tracks "$_sample_json" "all")
assert_contains "Extract all contains OP1" "$_tracks_all" "[OP1]"
assert_contains "Extract all contains Yuusha" "$_tracks_all" "Yuusha"
assert_contains "Extract all contains YOASOBI" "$_tracks_all" "YOASOBI"
assert_contains "Extract all contains ED1" "$_tracks_all" "[ED1]"
assert_contains "Extract all contains Anytime Anywhere" "$_tracks_all" "Anytime Anywhere"

_tracks_op=$(themes_extract_tracks "$_sample_json" "op")
assert_contains "Extract OP contains OP1" "$_tracks_op" "[OP1]"
_tracks_ed=$(themes_extract_tracks "$_sample_json" "ed")
assert_contains "Extract ED contains ED1" "$_tracks_ed" "[ED1]"

# Test 5: Playback dispatch with debug player
SRANIME_CLI_PLAYER="debug"
_debug_play=$(themes_play_track "https://v.animethemes.moe/test.webm" "Test Theme" "1")
assert_contains "Debug playback outputs title" "$_debug_play" "title=Test Theme"
assert_contains "Debug playback outputs audio_only" "$_debug_play" "audio_only=1"

_debug_dl=$(themes_download_track "https://v.animethemes.moe/test.webm" "frieren_op1.webm")
assert_contains "Debug download outputs url" "$_debug_dl" "url=https://v.animethemes.moe/test.webm"
assert_contains "Debug download outputs filename" "$_debug_dl" "filename=frieren_op1.webm"

print_test_summary
