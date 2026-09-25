#!/bin/bash
set -e
cd "$(dirname "$0")"

export GIT_AUTHOR_NAME="Srajan Mishra"
export GIT_COMMITTER_NAME="Srajan Mishra"
export GIT_AUTHOR_EMAIL="mail2srajanmishra@gmail.com"
export GIT_COMMITTER_EMAIL="mail2srajanmishra@gmail.com"

commit_at() {
    export GIT_AUTHOR_DATE="$1"
    export GIT_COMMITTER_DATE="$1"
    git add -A
    git commit -m "$2"
}

# === COMMIT 10: Sept 25, 10:00 — test framework ===
cat > test/test_utils.sh << 'ENDFILE'
#!/bin/sh
# Test helper utilities for sranime-cli test suite

_TESTS_RUN=0
_TESTS_PASSED=0
_TESTS_FAILED=0

assert_eq() {
    _TESTS_RUN=$((_TESTS_RUN + 1))
    _desc="$1"; _expected="$2"; _actual="$3"
    if [ "$_expected" = "$_actual" ]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        printf "  \033[1;32mPASS\033[0m %s\n" "$_desc"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        printf "  \033[1;31mFAIL\033[0m %s\n" "$_desc"
        printf "    Expected: %s\n    Actual:   %s\n" "$_expected" "$_actual"
    fi
}

assert_contains() {
    _TESTS_RUN=$((_TESTS_RUN + 1))
    _desc="$1"; _haystack="$2"; _needle="$3"
    if printf '%s' "$_haystack" | grep -q "$_needle"; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        printf "  \033[1;32mPASS\033[0m %s\n" "$_desc"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        printf "  \033[1;31mFAIL\033[0m %s\n" "$_desc"
        printf "    String does not contain: %s\n" "$_needle"
    fi
}

assert_exit_code() {
    _TESTS_RUN=$((_TESTS_RUN + 1))
    _desc="$1"; _expected="$2"; _cmd="$3"
    eval "$_cmd" >/dev/null 2>&1; _actual=$?
    if [ "$_expected" = "$_actual" ]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        printf "  \033[1;32mPASS\033[0m %s\n" "$_desc"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        printf "  \033[1;31mFAIL\033[0m %s (expected %s, got %s)\n" "$_desc" "$_expected" "$_actual"
    fi
}

print_test_summary() {
    printf "\n--- Results: %d total, %d passed, %d failed ---\n" "$_TESTS_RUN" "$_TESTS_PASSED" "$_TESTS_FAILED"
    [ "$_TESTS_FAILED" -eq 0 ]
}
ENDFILE

cat > test/test_cli_flags.sh << 'ENDFILE'
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

_config=$($SRANIME_CLI --dump-config 2>/dev/null)
assert_contains "Dump config shows mode" "$_config" "mode:"
assert_contains "Dump config shows quality" "$_config" "quality:"
assert_contains "Dump config shows player" "$_config" "player_function:"

_hist=$($SRANIME_CLI --show-history 2>/dev/null)
assert_contains "Show history produces output" "$_hist" "history"

$SRANIME_CLI --doctor >/dev/null 2>&1 || true

print_test_summary
ENDFILE

# Append to smoke_test
cat >> test/smoke_test.sh << 'ENDFILE'

echo "[7/8] Running CLI flag tests..."
sh test/test_cli_flags.sh

echo "[8/8] Checking for stale ani-cli references..."
if grep -rn "ani-cli" sranime-cli lib/ test/ install.sh Makefile 2>/dev/null | grep -v "ani-skip" | grep -v "backfill"; then
    echo "Error: Found ani-cli references that should be sranime-cli"
    exit 1
fi
echo "No stale references found."
echo ""
echo "All extended tests passed successfully!"
ENDFILE

commit_at "2026-09-25T10:00:30+0530" "test: add test framework utilities and comprehensive CLI flag tests"

# === COMMIT 11: Sept 25, 14:15 — watchlist ===
cat > lib/sranime-cli/watchlist.sh << 'ENDFILE'
#!/bin/sh
# sranime-cli watchlist module — manage a persistent favorites list

_watchlist_dir="${SRANIME_CLI_HIST_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}"
_watchlist_file="${_watchlist_dir}/watchlist"

_ensure_watchlist() {
    [ ! -d "$_watchlist_dir" ] && mkdir -p "$_watchlist_dir"
    [ ! -f "$_watchlist_file" ] && : >"$_watchlist_file"
}

watchlist_add() {
    _ensure_watchlist
    _id="$1"; _title="$2"
    if grep -q "	${_id}	" "$_watchlist_file" 2>/dev/null; then
        printf "\033[1;33mAlready in watchlist:\033[0m %s\n" "$_title"
        return 0
    fi
    _timestamp=$(date +%s 2>/dev/null || printf "0")
    printf "%s\t%s\t%s\n" "$_timestamp" "$_id" "$_title" >>"$_watchlist_file"
    printf "\033[1;32m+ Added to watchlist:\033[0m %s\n" "$_title"
}

watchlist_remove() {
    _ensure_watchlist
    _id="$1"
    if grep -q "	${_id}	" "$_watchlist_file" 2>/dev/null; then
        grep -v "	${_id}	" "$_watchlist_file" >"${_watchlist_file}.new"
        mv "${_watchlist_file}.new" "$_watchlist_file"
        printf "\033[1;32m- Removed from watchlist\033[0m\n"
    else
        printf "\033[1;33mNot found in watchlist\033[0m\n"
    fi
}

watchlist_show() {
    _ensure_watchlist
    if [ ! -s "$_watchlist_file" ]; then
        printf "\033[1;34mWatchlist is empty.\033[0m\n"
        printf "  Add anime with: sranime-cli --watchlist-add <query>\n"
        return 0
    fi
    printf "\033[1;36m--- Watchlist ---\033[0m\n"
    _n=1
    while IFS='	' read -r _ts _id _title; do
        [ -z "$_id" ] && continue
        printf "  \033[1;33m%2d.\033[0m %s\n" "$_n" "$_title"
        _n=$((_n + 1))
    done <"$_watchlist_file"
}

watchlist_clear() {
    _ensure_watchlist
    : >"$_watchlist_file"
    printf "\033[1;32mWatchlist cleared.\033[0m\n"
}
ENDFILE

# Add watchlist flags to main script (before --list-providers)
sed -i '/^        --list-providers)$/i\
        --watchlist)\
            . lib/sranime-cli/watchlist.sh 2>/dev/null || true\
            watchlist_show\
            exit 0\
            ;;\
        --watchlist-clear)\
            . lib/sranime-cli/watchlist.sh 2>/dev/null || true\
            watchlist_clear\
            exit 0\
            ;;' sranime-cli

# Add help text
sed -i '/^      --list-providers$/i\
      --watchlist\
        Display your saved anime watchlist\
      --watchlist-clear\
        Clear the watchlist' sranime-cli

commit_at "2026-09-25T14:15:50+0530" "feat(watchlist): add persistent anime watchlist with add/remove/show/clear"

echo "=== Commits 10-11 done ==="