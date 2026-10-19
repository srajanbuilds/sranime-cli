#!/bin/sh
# Unit tests for lib/sranime-cli/download.sh
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE_DIR/test/test_utils.sh"

export SRANIME_LIB_DIR="$BASE_DIR/lib/sranime-cli"
. "$BASE_DIR/lib/sranime-cli/download.sh"

printf "\033[1;36mRunning download module tests...\033[0m\n"

# Test 1: sanitize_filename removes illegal characters
s1=$(sanitize_filename "Frieren: Beyond Journey's End / Episode 12?")
assert_contains "Colons and slashes sanitized" "$s1" "Frieren - Beyond Journey's End - Episode 12"

s2=$(sanitize_filename 'Attack on Titan: The Final Season <Part 3> "Special"')
assert_contains "Angle brackets and quotes sanitized" "$s2" "Attack on Titan - The Final Season Part 3 Special"

# Test 2: detect_best_downloader for HLS (.m3u8) streams
d_hls=$(detect_best_downloader "https://example.com/stream/master.m3u8")
if command -v yt-dlp >/dev/null 2>&1; then
    assert_eq "HLS stream prefers yt-dlp when available" "yt-dlp" "$d_hls"
elif command -v ffmpeg >/dev/null 2>&1; then
    assert_eq "HLS stream prefers ffmpeg when available" "ffmpeg" "$d_hls"
else
    assert_contains "HLS stream picks viable tool" "aria2c yt-dlp ffmpeg curl" "$d_hls"
fi

# Test 3: detect_best_downloader for direct MP4 streams
d_mp4=$(detect_best_downloader "https://example.com/video/ep1.mp4")
if command -v aria2c >/dev/null 2>&1; then
    assert_eq "MP4 stream prefers aria2c when available" "aria2c" "$d_mp4"
elif command -v yt-dlp >/dev/null 2>&1; then
    assert_eq "MP4 stream prefers yt-dlp when available" "yt-dlp" "$d_mp4"
fi

# Test 4: download_stream handles empty URL
if download_stream "" "Title" "/tmp"; then
    res_empty="ok"
else
    res_empty="fail"
fi
assert_eq "download_stream rejects empty url" "fail" "$res_empty"

# Test 5: download_stream creates output directory
test_out_dir="$(mktemp -d 2>/dev/null || mktemp -d -t 'sranime_dl_test')/subdir"
# Call with invalid url to test directory creation without downloading
download_stream "invalid://protocol" "Test" "$test_out_dir" >/dev/null 2>&1 || true
assert_eq "Output directory created automatically" "1" "$([ -d "$test_out_dir" ] && echo 1 || echo 0)"


# Test 6: parse_episode_range with standard ranges
r_hyphen=$(parse_episode_range "1-5" 10 | tr '\n' ' ')
assert_eq "parse_episode_range handles hyphens" "1 2 3 4 5 " "$r_hyphen"

# Test 7: parse_episode_range with commas and mixed ranges
r_mixed=$(parse_episode_range "1,3,5-7,10" 12 | tr '\n' ' ')
assert_eq "parse_episode_range handles mixed commas and hyphens" "1 3 5 6 7 10 " "$r_mixed"

# Test 8: parse_episode_range with 'all'
r_all=$(parse_episode_range "all" 4 | tr '\n' ' ')
assert_eq "parse_episode_range handles all keyword" "1 2 3 4 " "$r_all"

# Test 9: format_season_path generates Plex-compliant paths
p_season=$(format_season_path "/downloads" "Frieren: Beyond Journey's End" 4 1 1080p)
assert_contains "format_season_path includes sanitized anime title" "$p_season" "Frieren - Beyond Journey's End"
assert_contains "format_season_path includes Season 01" "$p_season" "Season 01"
assert_contains "format_season_path includes S01E04" "$p_season" "S01E04"
assert_contains "format_season_path includes quality tag" "$p_season" "[1080p]"

# Test 10: download_batch_summary formats queue
sum_out=$(download_batch_summary "1
2
3")
assert_contains "download_batch_summary includes Total Episodes" "$sum_out" "Total Episodes"
assert_contains "download_batch_summary includes count" "$sum_out" "3"
assert_contains "download_batch_summary includes Queue List" "$sum_out" "Queue List"
assert_contains "download_batch_summary includes items" "$sum_out" "1 2 3"

# Test 11: download_format_rate_limit
assert_eq "download_format_rate_limit aria2c" "--max-download-limit=5M" "$(download_format_rate_limit "aria2c" "5M")"
assert_eq "download_format_rate_limit yt-dlp" "--limit-rate 5M" "$(download_format_rate_limit "yt-dlp" "5M")"
assert_eq "download_format_rate_limit curl" "--limit-rate 5M" "$(download_format_rate_limit "curl" "5M")"

# Cleanup
rm -rf "${test_out_dir%/*}" 2>/dev/null || true

print_test_summary
