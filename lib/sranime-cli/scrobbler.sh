#!/bin/sh
# sranime-cli scrobbler module — cloud tracker synchronization (AniList & MyAnimeList)
#
# Provides:
#   - scrobble_login <service> [token] : Authenticate with cloud anime trackers
#   - scrobble_status                  : Display status of authenticated services
#   - scrobble_logout [service]        : Remove stored credentials
#   - scrobble_verify_anilist <token>  : Validate token and fetch viewer info

_auth_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sranime-cli"
_auth_file="${_auth_dir}/auth.json"

_ensure_auth_dir() {
    [ ! -d "$_auth_dir" ] && mkdir -p "$_auth_dir" 2>/dev/null || true
}

_open_browser() {
    _url="$1"
    case "$(uname -s 2>/dev/null)" in
        *Darwin*)
            open "$_url" 2>/dev/null || true
            ;;
        *MINGW* | *MSYS* | *CYGWIN*)
            if command -v cmd.exe >/dev/null 2>&1; then
                cmd.exe /c start "" "$_url" 2>/dev/null || true
            elif command -v explorer.exe >/dev/null 2>&1; then
                explorer.exe "$_url" 2>/dev/null || true
            fi
            ;;
        *)
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$_url" 2>/dev/null || true
            fi
            ;;
    esac
}

_load_auth() {
    _anilist_token=""
    _anilist_uid=""
    _anilist_uname=""
    _mal_token=""
    _mal_uname=""
    [ ! -f "$_auth_file" ] && return 0

    if command -v jq >/dev/null 2>&1; then
        _anilist_token=$(jq -r '.anilist.token // empty' "$_auth_file" 2>/dev/null || true)
        _anilist_uid=$(jq -r '.anilist.user_id // empty' "$_auth_file" 2>/dev/null || true)
        _anilist_uname=$(jq -r '.anilist.user_name // empty' "$_auth_file" 2>/dev/null || true)
        _mal_token=$(jq -r '.mal.token // empty' "$_auth_file" 2>/dev/null || true)
        _mal_uname=$(jq -r '.mal.user_name // empty' "$_auth_file" 2>/dev/null || true)
    else
        _anilist_token=$(sed -nE 's/.*"token"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' "$_auth_file" | head -n 1)
        _anilist_uid=$(sed -nE 's/.*"user_id"[[:space:]]*:[[:space:]]*"?([0-9]*)"?.*/\1/p' "$_auth_file" | head -n 1)
        _anilist_uname=$(sed -nE 's/.*"user_name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' "$_auth_file" | head -n 1)
    fi
}

_save_auth() {
    _ensure_auth_dir
    (
        umask 077
        cat << AUTHEOF > "$_auth_file"
{
  "anilist": {
    "token": "${_anilist_token:-}",
    "user_id": "${_anilist_uid:-}",
    "user_name": "${_anilist_uname:-}"
  },
  "mal": {
    "token": "${_mal_token:-}",
    "user_name": "${_mal_uname:-}"
  }
}
AUTHEOF
        chmod 600 "$_auth_file" 2>/dev/null || true
    )
}

# Verify AniList Token and return Viewer JSON
scrobble_verify_anilist() {
    _tok="$1"
    [ -z "$_tok" ] && return 1

    _query='{"query": "query { Viewer { id name } }"}'
    curl -sL --max-time 10 -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "Authorization: Bearer $_tok" \
        -d "$_query" \
        "https://graphql.anilist.co" 2>/dev/null
}

# Login flow
scrobble_login() {
    _service="$1"
    _token_arg="$2"

    case "$_service" in
        anilist)
            printf "\033[1;36m=== AniList OAuth2 Login ===\033[0m\n"
            _client_id="14184"
            _oauth_url="https://anilist.co/api/v2/oauth/authorize?client_id=${_client_id}&response_type=token"

            if [ -n "$_token_arg" ]; then
                _tok="$_token_arg"
            elif [ -n "$SRANIME_ANILIST_TOKEN" ]; then
                _tok="$SRANIME_ANILIST_TOKEN"
            else
                printf "Opening AniList authorization in your default browser...\n"
                _open_browser "$_oauth_url"
                printf "If the browser did not open, navigate to:\n  \033[1;34m%s\033[0m\n\n" "$_oauth_url"
                printf "\033[1;33mPaste your AniList Bearer Token: \033[0m"
                read -r _tok
            fi

            [ -z "$_tok" ] && { printf "\033[1;31mError: No token provided.\033[0m\n"; return 1; }

            printf "Verifying token with AniList...\n"
            _resp=$(scrobble_verify_anilist "$_tok")
            
            _uid=""
            _uname=""
            if command -v jq >/dev/null 2>&1; then
                _uid=$(printf '%s' "$_resp" | jq -r '.data.Viewer.id // empty' 2>/dev/null || true)
                _uname=$(printf '%s' "$_resp" | jq -r '.data.Viewer.name // empty' 2>/dev/null || true)
            else
                _uid=$(printf '%s' "$_resp" | sed -nE 's/.*"Viewer"[[:space:]]*:[[:space:]]*\{[[:space:]]*"id"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p')
                _uname=$(printf '%s' "$_resp" | sed -nE 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')
            fi

            if [ -n "$_uid" ] && [ -n "$_uname" ]; then
                _load_auth
                _anilist_token="$_tok"
                _anilist_uid="$_uid"
                _anilist_uname="$_uname"
                _save_auth
                printf "\033[1;32m✓ Successfully logged in as: %s (User ID: %s)\033[0m\n" "$_uname" "$_uid"
                printf "Credentials saved to %s (permissions: 0600)\n" "$_auth_file"
                return 0
            else
                printf "\033[1;31m✗ Verification failed. Token is invalid or expired.\033[0m\n"
                return 1
            fi
            ;;
        mal)
            printf "\033[1;36m=== MyAnimeList Login ===\033[0m\n"
            printf "MyAnimeList OAuth2 PKCE integration is scheduled for Phase 4 Sprint 2.\n"
            printf "Currently, AniList is the active tracking provider.\n"
            return 0
            ;;
        *)
            printf "Usage: sranime-cli --login [anilist|mal]\n"
            return 1
            ;;
    esac
}

# Display Status of connected trackers
scrobble_status() {
    _load_auth
    printf "\033[1;36m================ Cloud Tracker Status ================\033[0m\n"
    
    # AniList Status
    if [ -n "$_anilist_token" ] && [ -n "$_anilist_uname" ]; then
        printf "  \033[1;34mAniList\033[0m     : \033[1;32mConnected\033[0m\n"
        printf "    User      : \033[1;33m%s\033[0m (ID: %s)\n" "$_anilist_uname" "$_anilist_uid"
        printf "    Auto-Sync : Enabled (Scrobbles at 80%% completion)\n"
    else
        printf "  \033[1;34mAniList\033[0m     : \033[0;90mNot Connected\033[0m (Log in: sranime-cli --login anilist)\n"
    fi

    # MAL Status
    if [ -n "$_mal_token" ] && [ -n "$_mal_uname" ]; then
        printf "  \033[1;35mMyAnimeList\033[0m : \033[1;32mConnected\033[0m\n"
        printf "    User      : \033[1;33m%s\033[0m\n" "$_mal_uname"
    else
        printf "  \033[1;35mMyAnimeList\033[0m : \033[0;90mNot Connected\033[0m\n"
    fi

    printf "\033[1;36m======================================================\033[0m\n"
}

# Logout
scrobble_logout() {
    _service="$1"
    _load_auth

    case "$_service" in
        anilist)
            _anilist_token=""
            _anilist_uid=""
            _anilist_uname=""
            _save_auth
            printf "\033[1;32mLogged out from AniList.\033[0m\n"
            ;;
        mal)
            _mal_token=""
            _mal_uname=""
            _save_auth
            printf "\033[1;32mLogged out from MyAnimeList.\033[0m\n"
            ;;
        *)
            _anilist_token=""
            _anilist_uid=""
            _anilist_uname=""
            _mal_token=""
            _mal_uname=""
            _save_auth
            printf "\033[1;32mLogged out from all tracking services.\033[0m\n"
            ;;
    esac
}

_scrobble_cache_dir="${SRANIME_CLI_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/sranime-cli}"
_scrobble_cache_file="${_scrobble_cache_dir}/scrobble_id_map.tsv"

_ensure_scrobble_cache() {
    [ ! -d "$_scrobble_cache_dir" ] && mkdir -p "$_scrobble_cache_dir" 2>/dev/null || true
    [ ! -f "$_scrobble_cache_file" ] && : >"$_scrobble_cache_file" 2>/dev/null || true
}

# Resolve Anime Title to AniList Media ID (with local TSV caching)
# Usage: scrobble_resolve_media_id <anime_title>
scrobble_resolve_media_id() {
    _title="$1"
    [ -z "$_title" ] && return 1

    _ensure_scrobble_cache
    _clean_title=$(printf '%s' "$_title" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:punct:]]//g' | tr '[:upper:]' '[:lower:]')

    # 1. Check local cache
    if [ -s "$_scrobble_cache_file" ]; then
        _cached_id=$(grep "^${_clean_title}	" "$_scrobble_cache_file" 2>/dev/null | head -n 1 | cut -f 2 || true)
        if [ -n "$_cached_id" ]; then
            printf "%s" "$_cached_id"
            return 0
        fi
    fi

    # 2. Query AniList GraphQL Search API
    _safe_title=$(printf '%s' "$_title" | sed 's/"/\\"/g')
    _query=$(cat << GRAPHQLEOF
{"query": "query (\$search: String) { Media(search: \$search, type: ANIME) { id idMal title { romaji english } episodes } }", "variables": {"search": "$_safe_title"}}
GRAPHQLEOF
)

    _agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    _resp=$(curl -sL --max-time 6 -X POST         -H "Content-Type: application/json"         -H "Accept: application/json"         -H "User-Agent: $_agent"         -d "$_query"         "https://graphql.anilist.co" 2>/dev/null)

    _media_id=""
    _mal_id=""
    _romaji=""

    if command -v jq >/dev/null 2>&1; then
        _media_id=$(printf '%s' "$_resp" | jq -r '.data.Media.id // empty' 2>/dev/null || true)
        _mal_id=$(printf '%s' "$_resp" | jq -r '.data.Media.idMal // empty' 2>/dev/null || true)
        _romaji=$(printf '%s' "$_resp" | jq -r '.data.Media.title.romaji // empty' 2>/dev/null || true)
    else
        _media_id=$(printf '%s' "$_resp" | sed -nE 's/.*"Media"[[:space:]]*:[[:space:]]*\{[[:space:]]*"id"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p')
        _mal_id=$(printf '%s' "$_resp" | sed -nE 's/.*"idMal"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p')
        _romaji=$(printf '%s' "$_resp" | sed -nE 's/.*"romaji"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
    fi

    if [ -n "$_media_id" ]; then
        printf "%s	%s	%s	%s
" "$_clean_title" "$_media_id" "${_mal_id:-0}" "${_romaji:-$_title}" >>"$_scrobble_cache_file"
        printf "%s" "$_media_id"
        return 0
    fi

    return 1
}

# Dispatch Progress Mutation to AniList
# Usage: scrobble_sync_progress <media_id> <ep_no> [anime_title]
scrobble_sync_progress() {
    _mid="$1"
    _ep="$2"
    _title="${3:-Anime}"

    [ -z "$_mid" ] || [ -z "$_ep" ] && return 1

    # Extract integer episode number
    _clean_ep=$(printf '%s' "$_ep" | grep -o '^[0-9]\+' || true)
    [ -z "$_clean_ep" ] && return 1

    _load_auth
    [ -z "$_anilist_token" ] && return 1

    _mutation=$(cat << MUTEOF
{"query": "mutation (\$mediaId: Int, \$progress: Int) { SaveMediaListEntry(mediaId: \$mediaId, progress: \$progress, status: CURRENT) { id progress status } }", "variables": {"mediaId": $_mid, "progress": $_clean_ep}}
MUTEOF
)

    _agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    _resp=$(curl -sL --max-time 8 -X POST         -H "Content-Type: application/json"         -H "Accept: application/json"         -H "Authorization: Bearer $_anilist_token"         -H "User-Agent: $_agent"         -d "$_mutation"         "https://graphql.anilist.co" 2>/dev/null)

    if printf '%s' "$_resp" | grep -q '"status":"CURRENT"'; then
        printf "\033[1;32m✓ [AniList]\033[0m Scrobbled Ep %s of %s\n" "$_clean_ep" "$_title"
        if command -v notify_send >/dev/null 2>&1; then
            notify_send "AniList Scrobble" "Updated ${_title} to Episode ${_clean_ep}"
        fi
        return 0
    else
        return 1
    fi
}

# Prepare Lua script for MPV IPC/progress observation
# Usage: scrobble_prepare_script <trigger_file>
scrobble_prepare_script() {
    _trig="$1"
    [ -z "$_trig" ] && return 1

    _lua_file="${_trig}.lua"
    _clean_trig=$(printf '%s' "$_trig" | tr '\\' '/')

    cat << LUAEOF > "$_lua_file"
-- sranime-cli MPV scrobble trigger
local trigger_path = [=[$_clean_trig]=]
local triggered = false

local function trigger_scrobble()
    if not triggered then
        triggered = true
        local f = io.open(trigger_path, "w")
        if f then
            f:write("SCROBBLED\n")
            f:close()
        end
    end
end

mp.observe_property("percent-pos", "number", function(_, val)
    if val and val >= 80 then
        trigger_scrobble()
    end
end)

mp.register_event("end-file", function(event)
    if event and event.reason == "eof" then
        trigger_scrobble()
    end
end)
LUAEOF

    printf "%s" "$_lua_file"
}

# High-level scrobble dispatcher called during/after playback
# Usage: scrobble_episode <anime_title> <ep_no>
scrobble_episode() {
    _title="$1"
    _ep="$2"

    [ -z "$_title" ] || [ -z "$_ep" ] && return 1

    _load_auth
    [ -z "$_anilist_token" ] && return 0

    _mid=$(scrobble_resolve_media_id "$_title")
    if [ -n "$_mid" ]; then
        scrobble_sync_progress "$_mid" "$_ep" "$_title"
    fi
}
