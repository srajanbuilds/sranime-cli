#!/bin/sh
# test/test_subtitles.sh - Unit tests for multi-language subtitles subsystem

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$REPO_ROOT/lib/sranime-cli"

. "$SCRIPT_DIR/test_utils.sh"
. "$LIB_DIR/subtitles.sh"

printf "Running subtitles and multi-language audio module tests...\n"

# Test 1: Language code normalization
assert_eq "Spanish normalizes to es" "es" "$(subtitles_normalize_lang "Spanish")"
assert_eq "Español normalizes to es" "es" "$(subtitles_normalize_lang "Español")"
assert_eq "French normalizes to fr" "fr" "$(subtitles_normalize_lang "French")"
assert_eq "German normalizes to de" "de" "$(subtitles_normalize_lang "German")"
assert_eq "English normalizes to en" "en" "$(subtitles_normalize_lang "English")"
assert_eq "Italian normalizes to it" "it" "$(subtitles_normalize_lang "Italian")"
assert_eq "Portuguese normalizes to pt" "pt" "$(subtitles_normalize_lang "Portuguese")"
assert_eq "Arabic normalizes to ar" "ar" "$(subtitles_normalize_lang "Arabic")"
assert_eq "Japanese normalizes to ja" "ja" "$(subtitles_normalize_lang "Japanese")"

# Sample JSON mock from provider
MOCK_JSON='{"src":"https://cdn.example.com/master.m3u8","subtitles":[{"lang":"English","src":"https://cdn.example.com/sub-en.vtt","default":true},{"lang":"Spanish","src":"https://cdn.example.com/sub-es.vtt"},{"lang":"French","src":"https://cdn.example.com/sub-fr.vtt"}]}'

# Test 2: List available tracks
_tracks=$(subtitles_list_tracks_json "$MOCK_JSON")
assert_contains "Track list contains English" "$_tracks" "English"
assert_contains "Track list contains Spanish" "$_tracks" "Spanish"
assert_contains "Track list contains French" "$_tracks" "French"

# Test 3: Extract requested language
_es_sub=$(subtitles_extract_from_json "$MOCK_JSON" "es")
assert_eq "Extracts Spanish subtitle URL" "https://cdn.example.com/sub-es.vtt" "$_es_sub"

_fr_sub=$(subtitles_extract_from_json "$MOCK_JSON" "french")
assert_eq "Extracts French subtitle URL with name" "https://cdn.example.com/sub-fr.vtt" "$_fr_sub"

# Test 4: Fallback to default when language not found
_fallback=$(subtitles_extract_from_json "$MOCK_JSON" "russian")
assert_eq "Falls back to default English track" "https://cdn.example.com/sub-en.vtt" "$_fallback"

# Test 5: Player argument generation
_mpv_args=$(subtitles_get_player_args "mpv" "es" "ja" "/tmp/test.vtt")
assert_contains "MPV slang includes requested language" "$_mpv_args" "--slang=es,en"
assert_contains "MPV alang includes audio language" "$_mpv_args" "--alang=ja,ja,en"
assert_contains "MPV sub-file included" "$_mpv_args" "--sub-file=/tmp/test.vtt"

_vlc_args=$(subtitles_get_player_args "vlc" "fr" "ja" "/tmp/test.vtt")
assert_contains "VLC sub-language includes requested language" "$_vlc_args" "--sub-language=fr"

print_test_summary
