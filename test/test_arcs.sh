#!/bin/sh
# test/test_arcs.sh - Unit tests for Canonical Story Arc Marathon Engine

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
LIB_DIR="$REPO_ROOT/lib/sranime-cli"

. "$SCRIPT_DIR/test_utils.sh"
. "$LIB_DIR/arcs.sh"

printf "Running Canonical Story Arc Marathon Engine tests...\n"

# Test 1: Function definitions
assert_eq "arcs_slugify is defined" "0" "$(command -v arcs_slugify >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "arcs_has_data is defined" "0" "$(command -v arcs_has_data >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "arcs_list is defined" "0" "$(command -v arcs_list >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "arcs_get_range is defined" "0" "$(command -v arcs_get_range >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "arcs_get_name is defined" "0" "$(command -v arcs_get_name >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "arcs_get_synopsis is defined" "0" "$(command -v arcs_get_synopsis >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "arcs_print_summary is defined" "0" "$(command -v arcs_print_summary >/dev/null 2>&1 && echo 0 || echo 1)"
assert_eq "arcs_choose_interactive is defined" "0" "$(command -v arcs_choose_interactive >/dev/null 2>&1 && echo 0 || echo 1)"

# Test 2: Slugification
assert_eq "Slugify One Piece" "one-piece" "$(arcs_slugify 'One Piece')"
assert_eq "Slugify Naruto" "naruto" "$(arcs_slugify 'Naruto')"
assert_eq "Slugify Naruto Shippuden" "naruto-shippuden" "$(arcs_slugify 'Naruto: Shippuden')"
assert_eq "Slugify Bleach" "bleach" "$(arcs_slugify 'Bleach')"
assert_eq "Slugify Hunter x Hunter" "hunter-x-hunter" "$(arcs_slugify 'Hunter x Hunter (2011)')"
assert_eq "Slugify Dragon Ball Z" "dragon-ball-z" "$(arcs_slugify 'Dragon Ball Z')"
assert_eq "Slugify DBZ alias" "dragon-ball-z" "$(arcs_slugify 'DBZ')"
assert_eq "Slugify Jujutsu Kaisen" "jujutsu-kaisen" "$(arcs_slugify 'Jujutsu Kaisen Season 2')"
assert_eq "Slugify Kimetsu no Yaiba" "demon-slayer" "$(arcs_slugify 'Kimetsu no Yaiba: Yuukaku-hen')"

# Test 3: arcs_has_data check
assert_eq "Has data for One Piece" "0" "$(arcs_has_data 'One Piece' && echo 0 || echo 1)"
assert_eq "Has data for Naruto" "0" "$(arcs_has_data 'Naruto' && echo 0 || echo 1)"
assert_eq "Has data for Bleach" "0" "$(arcs_has_data 'Bleach' && echo 0 || echo 1)"
assert_eq "Has data for Unknown Anime" "1" "$(arcs_has_data 'Some Obscure 1980s OVA' && echo 0 || echo 1)"

# Test 4: One Piece Arcs resolution
assert_eq "One Piece Marineford range" "457-489" "$(arcs_get_range 'One Piece' 'Marineford')"
assert_eq "One Piece Enies Lobby range" "264-312" "$(arcs_get_range 'One Piece' 'enies-lobby')"
assert_eq "One Piece Wano Country range" "892-1085" "$(arcs_get_range 'One Piece' 'Wano')"
assert_eq "One Piece Egghead range" "1086-1122" "$(arcs_get_range 'One Piece' 'Egghead')"

# Test 5: Naruto Original Arcs
assert_eq "Naruto Chunin Exams range" "20-67" "$(arcs_get_range 'Naruto' 'Chunin Exams')"
assert_eq "Naruto Land of Waves range" "1-19" "$(arcs_get_range 'Naruto' 'Land of Waves')"
assert_eq "Naruto Sasuke Recovery range" "107-135" "$(arcs_get_range 'Naruto' 'sasuke-recovery')"

# Test 6: Naruto Shippuden Arcs
assert_eq "Shippuden Pain's Assault range" "152-175" "$(arcs_get_range 'Naruto Shippuden' 'Pain')"
assert_eq "Shippuden Fated Battle range" "134-143" "$(arcs_get_range 'Naruto Shippuden' 'Fated Battle')"

# Test 7: Bleach Arcs
assert_eq "Bleach TYBW range" "367-392" "$(arcs_get_range 'Bleach' 'Thousand-Year Blood War')"
assert_eq "Bleach Soul Society Rescue range" "42-63" "$(arcs_get_range 'Bleach' 'Soul Society: The Rescue')"

# Test 8: Hunter x Hunter Arcs
assert_eq "HxH Yorknew City range" "37-58" "$(arcs_get_range 'Hunter x Hunter' 'Yorknew City')"
assert_eq "HxH Chimera Ant range" "76-136" "$(arcs_get_range 'Hunter x Hunter' 'Chimera Ant')"

# Test 9: Dragon Ball Z Arcs
assert_eq "DBZ Saiyan Saga range" "1-35" "$(arcs_get_range 'Dragon Ball Z' 'Saiyan')"
assert_eq "DBZ Cell Saga range" "118-194" "$(arcs_get_range 'Dragon Ball Z' 'Cell')"
assert_eq "DBZ Majin Buu Saga range" "200-291" "$(arcs_get_range 'Dragon Ball Z' 'Majin Buu')"

# Test 10: Jujutsu Kaisen Arcs
assert_eq "JJK Shibuya Incident range" "30-47" "$(arcs_get_range 'Jujutsu Kaisen' 'Shibuya')"
assert_eq "JJK Hidden Inventory range" "25-29" "$(arcs_get_range 'Jujutsu Kaisen' 'Hidden Inventory')"

# Test 11: Demon Slayer Arcs
assert_eq "Demon Slayer Mugen Train range" "27-33" "$(arcs_get_range 'Demon Slayer' 'Mugen Train')"
assert_eq "Demon Slayer Entertainment District range" "34-44" "$(arcs_get_range 'Demon Slayer' 'Entertainment District')"

# Test 12: Case-insensitive query matching
assert_eq "Case-insensitive query" "457-489" "$(arcs_get_range 'One Piece' 'mArInEfOrD')"
assert_eq "Case-insensitive Chunin" "20-67" "$(arcs_get_range 'Naruto' 'cHunin')"

# Test 13: Substring matching
assert_eq "Substring match 'marine'" "457-489" "$(arcs_get_range 'One Piece' 'marine')"
assert_eq "Substring match 'chimera'" "76-136" "$(arcs_get_range 'Hunter x Hunter' 'chimera')"

# Test 14: Arc name retrieval
_op_name=$(arcs_get_name "One Piece" "marineford")
assert_contains "Arc name contains Marineford" "$_op_name" "Marineford"

# Test 15: Synopsis retrieval
_op_syn=$(arcs_get_synopsis "One Piece" "marineford")
assert_contains "Synopsis contains Whitebeard" "$_op_syn" "Whitebeard"

# Test 16: Summary card rendering
_summary_output=$(arcs_print_summary "One Piece" "Marineford")
assert_contains "Summary has header" "$_summary_output" "STORY ARC MARATHON"
assert_contains "Summary has episodes" "$_summary_output" "457 - 489"

print_test_summary
