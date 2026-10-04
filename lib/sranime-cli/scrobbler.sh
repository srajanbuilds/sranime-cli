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
