#!/bin/sh
# sranime-cli provider registry & multi-provider fallback engine
#
# Supported providers:
#   - hianime  (default primary, multi-server extraction)
#   - allanime (fast GraphQL API fallback)
#   - gogo     (gogoanime / anitaku HTML scraper fallback)

if [ -z "$PROVIDERS_DIR" ]; then
    if [ -n "$SRANIME_LIB_DIR" ] && [ -d "$SRANIME_LIB_DIR/providers" ]; then
        PROVIDERS_DIR="$SRANIME_LIB_DIR/providers"
    elif [ -d "lib/sranime-cli/providers" ]; then
        PROVIDERS_DIR="$(pwd)/lib/sranime-cli/providers"
    else
        PROVIDERS_DIR="/usr/local/lib/sranime-cli/providers"
    fi
fi
export PROVIDERS_DIR

AVAILABLE_PROVIDERS="hianime aniwatch 9anime allanime gogo"
ACTIVE_PROVIDER="${SRANIME_CLI_PROVIDER:-hianime}"

load_provider() {
    _prov="${1:-$ACTIVE_PROVIDER}"
    _pfile="${PROVIDERS_DIR}/${_prov}.sh"
    if [ -f "$_pfile" ]; then
        . "$_pfile"
    elif [ "$_prov" != "hianime" ]; then
        printf "\033[1;33m[provider]\033[0m Provider '%s' file not found at %s, using built-in\n" "$_prov" "$_pfile" >&2
    fi
}

# Search with automatic multi-provider fallback
# Usage: provider_search <query>
provider_search() {
    _query="$1"
    _results=""

    # 1. Try active provider
    case "$ACTIVE_PROVIDER" in
        aniwatch)
            _results=$(hianime_search "$_query" 2>/dev/null)
            ;;
        9anime)
            load_provider "allanime"
            _results=$(allanime_search "$_query" 2>/dev/null)
            ;;
        allanime)
            load_provider "allanime"
            _results=$(allanime_search "$_query" 2>/dev/null)
            ;;
        gogo)
            load_provider "gogo"
            _results=$(gogo_search "$_query" 2>/dev/null)
            ;;
        *)
            # Built-in hianime
            _results=$(hianime_search "$_query" 2>/dev/null)
            ;;
    esac

    # Return if successful
    if [ -n "$_results" ]; then
        printf '%s\n' "$_results"
        return 0
    fi

    # 2. If provider was forced by user, do not fallback
    if [ -n "$SRANIME_CLI_PROVIDER_FORCE" ]; then
        return 1
    fi

    # 3. Fallback chain
    for _fallback in $AVAILABLE_PROVIDERS; do
        [ "$_fallback" = "$ACTIVE_PROVIDER" ] && continue
        printf "\033[1;33m[sranime-cli]\033[0m %s returned no results, trying fallback: %s...\n" "$ACTIVE_PROVIDER" "$_fallback" >&2

        load_provider "$_fallback"
        case "$_fallback" in
            allanime) _results=$(allanime_search "$_query" 2>/dev/null) ;;
            gogo)     _results=$(gogo_search "$_query" 2>/dev/null) ;;
            hianime)  _results=$(hianime_search "$_query" 2>/dev/null) ;;
            aniwatch) _results=$(hianime_search "$_query" 2>/dev/null) ;;
            9anime)   _results=$(allanime_search "$_query" 2>/dev/null) ;;
        esac

        if [ -n "$_results" ]; then
            ACTIVE_PROVIDER="$_fallback"
            export ACTIVE_PROVIDER
            printf "\033[1;32m[sranime-cli]\033[0m Connected to provider: %s\n" "$ACTIVE_PROVIDER" >&2
            printf '%s\n' "$_results"
            return 0
        fi
    done

    return 1
}

# Fetch episode list for active provider
# Usage: provider_episodes <anime_id>
provider_episodes() {
    _id="$1"
    case "$ACTIVE_PROVIDER" in
        aniwatch)
            hianime_episodes "$_id"
            ;;
        9anime)
            load_provider "allanime"
            allanime_episodes "$_id"
            ;;
        allanime)
            load_provider "allanime"
            allanime_episodes "$_id"
            ;;
        gogo)
            load_provider "gogo"
            gogo_episodes "$_id"
            ;;
        *)
            hianime_episodes "$_id"
            ;;
    esac
}

# Check provider health
# Usage: check_provider_health <provider_name>
check_provider_health() {
    _p="$1"
    case "$_p" in
        hianime)  curl -sI --max-time 3 "https://hianime.at" >/dev/null 2>&1 ;;
        aniwatch) curl -sI --max-time 3 "https://aniwatchtv.to" >/dev/null 2>&1 ;;
        9anime)   curl -sI --max-time 3 "https://aniwave.to" >/dev/null 2>&1 ;;
        allanime) curl -sI --max-time 3 "https://api.allanime.day" >/dev/null 2>&1 ;;
        gogo)     curl -sI --max-time 3 "https://anitaku.to" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

# List available stream providers with status
list_providers() {
    printf "\033[1;36mAvailable Stream Providers:\033[0m\n\n"
    printf "  \033[1;32m* hianime\033[0m  (primary default)  - HiAnime / Zoro extraction engine\n"
    printf "    aniwatch (hianime mirror)   - AniWatch fast alternative mirror\n"
    printf "    9anime   (allanime fast)    - 9Anime / AniWave high-speed API\n"
    printf "    allanime (secondary backup) - AllAnime GraphQL API engine\n"
    printf "    gogo     (tertiary backup)  - GogoAnime / Anitaku scraper\n"
    printf "\nUsage: sranime-cli -p <provider> <query>\n"
}