#!/bin/sh
# Unit tests for lib/sranime-cli/providers.sh and provider plugins

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE_DIR/test/test_utils.sh"

export SRANIME_LIB_DIR="$BASE_DIR/lib/sranime-cli"
export PROVIDERS_DIR="$BASE_DIR/lib/sranime-cli/providers"
. "$BASE_DIR/lib/sranime-cli/providers.sh"

printf "\033[1;36mRunning providers module tests...\033[0m\n"

# Test 1: list_providers output
list_out=$(list_providers)
assert_contains "list_providers outputs hianime" "$list_out" "hianime"
assert_contains "list_providers outputs allanime" "$list_out" "allanime"
assert_contains "list_providers outputs gogo" "$list_out" "gogo"

# Test 2: Provider loading
load_provider "allanime"
allanime_loaded=$(command -v allanime_search >/dev/null && printf "yes" || printf "no")
assert_eq "allanime_search function is defined after load" "yes" "$allanime_loaded"

load_provider "gogo"
gogo_loaded=$(command -v gogo_search >/dev/null && printf "yes" || printf "no")
assert_eq "gogo_search function is defined after load" "yes" "$gogo_loaded"

# Test 3: Provider selection and fallback variables
ACTIVE_PROVIDER="hianime"
assert_eq "default active provider is hianime" "hianime" "$ACTIVE_PROVIDER"

ACTIVE_PROVIDER="allanime"
assert_eq "active provider can be switched to allanime" "allanime" "$ACTIVE_PROVIDER"

print_test_summary