#!/bin/sh
# Unit tests for lib/sranime-cli/preview.sh
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE_DIR/test/test_utils.sh"

export SRANIME_LIB_DIR="$BASE_DIR/lib/sranime-cli"
. "$BASE_DIR/lib/sranime-cli/preview.sh"

printf "\033[1;36mRunning preview module tests...\033[0m\n"

# Test 1: format_episodes_with_watched with empty watch history
test_eps="1
2
3
4"
res_empty=$(format_episodes_with_watched "$test_eps" "non-existent-anime-999")
assert_contains "Unwatched episode 1 has no badge" "$res_empty" "1"

# Test 2: format_episodes_with_watched with watched history
tmp_state="${HOME}/.cache/sranime_test_preview"
rm -rf "$tmp_state" 2>/dev/null || true
mkdir -p "$tmp_state" 2>/dev/null || true
export SRANIME_CLI_HIST_DIR="$tmp_state"
printf "2026-09-28 01:00:00\tWATCH\t2\ttest-hero-123\tTest Hero\thianime\n" > "$tmp_state/watch.log"

res_watched=$(format_episodes_with_watched "$test_eps" "test-hero-123")
assert_contains "Watched episode 2 has [Watched] badge" "$res_watched" "2  ✓ [Watched]"

# Test 3: parse_search_cards extraction
sample_html='<div class="flw-item">
    <div class="film-poster">
        <div class="tick ltr">
            <div class="tick-item tick-sub"><i class="fas fa-closed-captioning mr-1"></i>24</div>
            <div class="tick-item tick-dub"><i class="fas fa-microphone mr-1"></i>12</div>
        </div>
        <img src="https://example.com/poster.jpg" class="film-poster-img" alt="Test Hero">
    </div>
    <div class="film-detail">
        <h3 class="film-name">
            <a href="https://hianime.at/test-hero-123" title="Test Hero" data-jname="Boku no Hero">Test Hero</a>
        </h3>
        <div class="description">A young hero fights against evil in a bustling city.</div>
        <div class="fd-infor">
            <span class="fdi-item">TV</span>
            <span class="fdi-item fdi-duration">24m</span>
        </div>
    </div>
</div>'

tmp_tsv="$tmp_state/test_cards.tsv"
: > "$tmp_tsv"
parse_search_cards "$sample_html" "$tmp_tsv"

assert_eq "parse_search_cards generated 1 entry" "1" "$(wc -l < "$tmp_tsv" | tr -d ' ')"
tsv_row=$(cat "$tmp_tsv")
assert_contains "TSV contains ID" "$tsv_row" "test-hero-123"
assert_contains "TSV contains English title" "$tsv_row" "Test Hero"
assert_contains "TSV contains Japanese name" "$tsv_row" "Boku no Hero"
assert_contains "TSV contains format TV" "$tsv_row" "TV"
assert_contains "TSV contains duration" "$tsv_row" "24m"
assert_contains "TSV contains sub count" "$tsv_row" "24"
assert_contains "TSV contains dub count" "$tsv_row" "12"

# Test 4: preview_anime output formatting
export SRANIME_CLI_PREVIEW_TSV="$tmp_tsv"
card_output=$(preview_anime "test-hero-123	Test Hero")
assert_contains "Preview card has title" "$card_output" "Test Hero"
assert_contains "Preview card has Romaji title" "$card_output" "Boku no Hero"
assert_contains "Preview card shows format" "$card_output" "Format:"
assert_contains "Preview card shows episodes" "$card_output" "Episodes:"
assert_contains "Preview card shows sub count" "$card_output" "24"
assert_contains "Preview card shows dub count" "$card_output" "12"
assert_contains "Preview card shows watch history" "$card_output" "In Progress"
assert_contains "Preview card has synopsis" "$card_output" "A young hero fights"

# Test 5: CLI flag integration
cli_preview=$("$BASE_DIR/sranime-cli" --preview "test-hero-123	Test Hero" 2>/dev/null)
assert_contains "CLI --preview outputs card" "$cli_preview" "Test Hero"

# Cleanup
rm -rf "$tmp_state" 2>/dev/null || true

print_test_summary
