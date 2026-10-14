#!/bin/sh
# Unit tests for lib/sranime-cli/nfo.sh
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE_DIR/test/test_utils.sh"

TEST_NFO_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'sranime_nfo_test')"
export SRANIME_LIB_DIR="$BASE_DIR/lib/sranime-cli"

. "$BASE_DIR/lib/sranime-cli/nfo.sh"

printf "\033[1;36mRunning NFO and artwork module tests...\033[0m\n"

# Test 1: nfo_generate_tvshow creates valid XML
nfo_generate_tvshow "$TEST_NFO_DIR" "Sousou no Frieren" "Frieren: Beyond Journey's End" "After defeating the demon king..." "2023" "Madhouse" "Adventure,Drama,Fantasy" "9.1" "154587" "52991" >/dev/null 2>&1
assert_eq "tvshow.nfo exists" "1" "$([ -f "$TEST_NFO_DIR/tvshow.nfo" ] && echo 1 || echo 0)"

nfo_content=$(cat "$TEST_NFO_DIR/tvshow.nfo")
assert_contains "NFO contains tvshow root" "$nfo_content" "<tvshow>"
assert_contains "NFO contains title" "$nfo_content" "<title>Sousou no Frieren</title>"
assert_contains "NFO contains originaltitle" "$nfo_content" "<originaltitle>Frieren: Beyond Journey's End</originaltitle>"
assert_contains "NFO contains studio" "$nfo_content" "<studio>Madhouse</studio>"
assert_contains "NFO contains year" "$nfo_content" "<year>2023</year>"
assert_contains "NFO contains genre Adventure" "$nfo_content" "<genre>Adventure</genre>"
assert_contains "NFO contains rating" "$nfo_content" "<rating>9.1</rating>"
assert_contains "NFO contains anilist uniqueid" "$nfo_content" '<uniqueid type="anilist" default="true">154587</uniqueid>'
assert_contains "NFO contains mal uniqueid" "$nfo_content" '<uniqueid type="mal">52991</uniqueid>'

# Test 2: nfo_generate_episode creates valid episode XML
ep_nfo="$TEST_NFO_DIR/Season 01/Frieren - S01E14.nfo"
nfo_generate_episode "$ep_nfo" "Sousou no Frieren" "14" "Privilege of the Young" "Stark and Fern dance." "1" >/dev/null 2>&1
assert_eq "Episode .nfo exists" "1" "$([ -f "$ep_nfo" ] && echo 1 || echo 0)"

ep_content=$(cat "$ep_nfo")
assert_contains "Episode NFO contains episodedetails root" "$ep_content" "<episodedetails>"
assert_contains "Episode NFO contains episode title" "$ep_content" "<title>Privilege of the Young</title>"
assert_contains "Episode NFO contains season 1" "$ep_content" "<season>1</season>"
assert_contains "Episode NFO contains episode 14" "$ep_content" "<episode>14</episode>"
assert_contains "Episode NFO contains plot" "$ep_content" "<plot>Stark and Fern dance.</plot>"

# Test 3: nfo_save_subtitles rejects empty parameters
_act=0
nfo_save_subtitles "" "" >/dev/null 2>&1 || _act=$?
assert_eq "nfo_save_subtitles rejects empty parameters" "1" "$_act"

# Test 4: nfo_enrich_and_generate creates both show and episode NFOs
test_vid="$TEST_NFO_DIR/Bocchi/Season 01/Bocchi the Rock! - S01E01.mp4"
mkdir -p "$(dirname "$test_vid")"
touch "$test_vid"
nfo_enrich_and_generate "$test_vid" "Bocchi the Rock!" "1" "1" "" "" >/dev/null 2>&1

assert_eq "Enrichment creates tvshow.nfo" "1" "$([ -f "$TEST_NFO_DIR/Bocchi/tvshow.nfo" ] && echo 1 || echo 0)"
assert_eq "Enrichment creates episode.nfo" "1" "$([ -f "$TEST_NFO_DIR/Bocchi/Season 01/Bocchi the Rock! - S01E01.nfo" ] && echo 1 || echo 0)"

# Cleanup
rm -rf "$TEST_NFO_DIR" 2>/dev/null || true

print_test_summary
