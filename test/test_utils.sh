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
    if printf '%s' "$_haystack" | grep -q -F -e "$_needle"; then
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
    _actual=0
    eval "$_cmd" >/dev/null 2>&1 || _actual=$?
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
