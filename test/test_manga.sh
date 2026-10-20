#!/bin/sh
# test/test_manga.sh - Unit tests for Manga Companion & Reader subsystem

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$REPO_ROOT/lib/sranime-cli"

. "$SCRIPT_DIR/test_utils.sh"
. "$LIB_DIR/manga.sh"

printf "Running Manga Companion & Reader module tests...\n"

# Test 1: Function definitions
assert_eq "manga_search is defined" "0" "$(command -v manga_search >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "manga_parse_search is defined" "0" "$(command -v manga_parse_search >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "manga_list_chapters is defined" "0" "$(command -v manga_list_chapters >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "manga_fetch_pages is defined" "0" "$(command -v manga_fetch_pages >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "manga_read_chapter is defined" "0" "$(command -v manga_read_chapter >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "manga_download_chapter is defined" "0" "$(command -v manga_download_chapter >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "manga_save_checkpoint is defined" "0" "$(command -v manga_save_checkpoint >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "manga_get_checkpoint is defined" "0" "$(command -v manga_get_checkpoint >/dev/null 2>&1 && echo 0 || echo 1)"

# Test 2: Search rejects empty query
assert_exit_code "manga_search rejects empty query" 1 "manga_search ''"

# Test 3: Mock search JSON parsing
_mock_search='{"data":[{"id":"bda37780-fd27-4638-8686-77889a07174e","attributes":{"title":{"en":"Sousou no Frieren"},"year":2020,"status":"ongoing"}}]}'
_parsed_search=$(manga_parse_search "$_mock_search")
assert_contains "Parsed search contains Frieren" "$_parsed_search" "Sousou no Frieren"
assert_contains "Parsed search contains year" "$_parsed_search" "2020"
assert_contains "Parsed search contains ID" "$_parsed_search" "bda37780"

# Test 4: Checkpoints storage and retrieval
_tmp_state=$(mktemp -d 2>/dev/null || echo "/tmp/test_manga_state")
mkdir -p "$_tmp_state"
SRANIME_CLI_STATE_DIR="$_tmp_state"
_manga_state_dir="$_tmp_state"
_manga_cp_file="$_tmp_state/manga_checkpoints.tsv"

manga_save_checkpoint "Sousou no Frieren" "61" "14"
assert_eq "Checkpoint file created" "0" "$([ -f "$_manga_cp_file" ] && echo 0 || echo 1)"

_cp=$(manga_get_checkpoint "Sousou no Frieren")
assert_contains "Checkpoint has chapter 61" "$_cp" "61"
assert_contains "Checkpoint has page 14" "$_cp" "14"

# Test 5: Debug read and download dispatch
SRANIME_CLI_PLAYER="debug"
_debug_read=$(manga_read_chapter "test_ch_id" "Frieren" "61")
assert_contains "Debug read outputs id" "$_debug_read" "id=test_ch_id"
assert_contains "Debug read outputs chapter" "$_debug_read" "chapter=61"

_debug_dl=$(manga_download_chapter "test_ch_id" "Frieren" "61")
assert_contains "Debug download outputs id" "$_debug_dl" "id=test_ch_id"
assert_contains "Debug download outputs chapter" "$_debug_dl" "chapter=61"

rm -rf "$_tmp_state" 2>/dev/null || true
print_test_summary
