#!/bin/sh
# test/test_filler.sh - Unit tests for Smart Filler Episode Badges & Skipping Engine

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$REPO_ROOT/lib/sranime-cli"

. "$SCRIPT_DIR/test_utils.sh"
. "$LIB_DIR/filler.sh"

printf "Running Smart Filler Episode Badges & Skipper module tests...\n"

# Test 1: Function definitions
assert_eq "filler_slugify is defined" "0" "$(command -v filler_slugify >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "filler_get_episode_status is defined" "0" "$(command -v filler_get_episode_status >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "filler_format_badge is defined" "0" "$(command -v filler_format_badge >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "filler_enrich_episode_list is defined" "0" "$(command -v filler_enrich_episode_list >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "filler_is_filler is defined" "0" "$(command -v filler_is_filler >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "filler_find_next_canon is defined" "0" "$(command -v filler_find_next_canon >/dev/null 2>&1 && echo 0 || echo 1)"

# Test 2: Title slugification
assert_eq "Slugify standard title" "naruto" "$(filler_slugify 'Naruto')"
assert_eq "Slugify title with colon" "naruto-shippuden" "$(filler_slugify 'Naruto: Shippuden')"
assert_eq "Slugify Bleach" "bleach" "$(filler_slugify 'Bleach')"

# Test 3: Naruto classifications (Ep 1 = Canon, Ep 136 = Filler)
assert_eq "Naruto Ep 1 is Manga Canon" "MANGA_CANON" "$(filler_get_episode_status 'Naruto' '1')"
assert_eq "Naruto Ep 136 is Filler" "FILLER" "$(filler_get_episode_status 'Naruto' '136')"

# Test 4: Bleach classifications (Ep 63 = Canon, Ep 64 = Bount Arc Filler)
assert_eq "Bleach Ep 63 is Manga Canon" "MANGA_CANON" "$(filler_get_episode_status 'Bleach' '63')"
assert_eq "Bleach Ep 64 is Filler" "FILLER" "$(filler_get_episode_status 'Bleach' '64')"

# Test 5: Badge formatting
_canon_badge=$(filler_format_badge "MANGA_CANON")
assert_contains "Canon badge contains [Canon]" "$_canon_badge" "[Canon]"
_filler_badge=$(filler_format_badge "FILLER")
assert_contains "Filler badge contains [Filler]" "$_filler_badge" "[Filler]"

# Test 6: Episode list enrichment
_raw_eps="63
64
65"
_enriched=$(filler_enrich_episode_list "$(printf "%b" "$_raw_eps")" "Bleach" "0")
assert_contains "Enriched list has Ep 63 Canon" "$_enriched" "Episode 63"
assert_contains "Enriched list has Ep 64 Filler" "$_enriched" "[Filler]"

# Test 7: Canon-only filtering drops filler
_canon_only=$(filler_enrich_episode_list "$(printf "%b" "$_raw_eps")" "Bleach" "1")
assert_contains "Canon-only contains Ep 63" "$_canon_only" "Episode 63"
if printf "%s" "$_canon_only" | grep -q "Episode 64"; then
    assert_eq "Canon-only excludes Ep 64" "0" "1"
else
    assert_eq "Canon-only excludes Ep 64" "0" "0"
fi

# Test 8: Skip filler jumps to next canon
_all_eps="63 64 65 109"
_next=$(filler_find_next_canon "Bleach" "63" "$_all_eps")
assert_eq "Find next canon after 63 skips 64/65 to 109" "109" "$_next"

print_test_summary
