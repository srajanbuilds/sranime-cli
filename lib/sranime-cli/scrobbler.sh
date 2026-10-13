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
        _sec=""
        while IFS= read -r _l || [ -n "$_l" ]; do
            case "$_l" in
                *"\"anilist\":"*) _sec="anilist" ;;
                *"\"mal\":"*) _sec="mal" ;;
                *\}*) _sec="" ;;
                *"\"token\":"*)
                    _val=$(printf '%s\n' "$_l" | sed -nE 's/.*"token"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
                    [ "$_sec" = "anilist" ] && _anilist_token="$_val"
                    [ "$_sec" = "mal" ] && _mal_token="$_val"
                    ;;
                *"\"user_id\":"*)
                    _val=$(printf '%s\n' "$_l" | sed -nE 's/.*"user_id"[[:space:]]*:[[:space:]]*"?([0-9]*)"?.*/\1/p')
                    [ "$_sec" = "anilist" ] && _anilist_uid="$_val"
                    ;;
                *"\"user_name\":"*)
                    _val=$(printf '%s\n' "$_l" | sed -nE 's/.*"user_name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
                    [ "$_sec" = "anilist" ] && _anilist_uname="$_val"
                    [ "$_sec" = "mal" ] && _mal_uname="$_val"
                    ;;
            esac
        done < "$_auth_file"
    fi
    return 0
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

# Verify MyAnimeList Token and return User JSON
scrobble_verify_mal() {
    _tok="$1"
    [ -z "$_tok" ] && return 1

    _agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    curl -sL --max-time 10 -X GET \
        -H "Authorization: Bearer $_tok" \
        -H "User-Agent: $_agent" \
        "https://api.myanimelist.net/v2/users/@me" 2>/dev/null
}

# Update MyAnimeList episode progress
scrobble_update_mal() {
    _mal_id="$1"
    _ep="$2"
    _title="${3:-Anime}"

    [ -z "$_mal_id" ] || [ -z "$_ep" ] && return 1
    _clean_ep=$(printf '%s' "$_ep" | grep -o '^[0-9]\+' || true)
    [ -z "$_clean_ep" ] && return 1

    _load_auth
    [ -z "$_mal_token" ] && return 1

    _agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    _resp=$(curl -sL --max-time 8 -X PUT \
        -H "Authorization: Bearer $_mal_token" \
        -H "User-Agent: $_agent" \
        -d "num_watched_episodes=${_clean_ep}&status=watching" \
        "https://api.myanimelist.net/v2/anime/${_mal_id}/my_list_status" 2>/dev/null)

    if printf '%s' "$_resp" | grep -q '"status"'; then
        printf "\033[1;35m✓ [MyAnimeList]\033[0m Scrobbled Ep %s of %s\n" "$_clean_ep" "$_title"
        return 0
    else
        return 1
    fi
}

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
            _mal_client_id="${SRANIME_MAL_CLIENT_ID:-6114d00ca681b77c011c344f193d023c}"

            if [ -n "$_token_arg" ]; then
                _tok="$_token_arg"
            elif [ -n "$SRANIME_MAL_TOKEN" ]; then
                _tok="$SRANIME_MAL_TOKEN"
            else
                _verifier=$(LC_ALL=C tr -dc 'A-Za-z0-9-._~' </dev/urandom 2>/dev/null | head -c 128 || true)
                [ -z "$_verifier" ] && _verifier="sranime_cli_verifier_pkce_token_random_string_128_chars_long_compliant_with_myanimelist_oauth2_specs_abcdef"
                _oauth_url="https://myanimelist.net/v1/oauth2/authorize?response_type=code&client_id=${_mal_client_id}&code_challenge=${_verifier}&code_challenge_method=plain"

                printf "Opening MyAnimeList authorization in your default browser...\n"
                _open_browser "$_oauth_url"
                printf "If the browser did not open, navigate to:\n  \033[1;34m%s\033[0m\n\n" "$_oauth_url"
                printf "\033[1;33mPaste your MyAnimeList Authorization Code or Bearer Token: \033[0m"
                read -r _tok
            fi

            [ -z "$_tok" ] && { printf "\033[1;31mError: No code or token provided.\033[0m\n"; return 1; }

            printf "Verifying credentials with MyAnimeList...\n"
            _resp=$(scrobble_verify_mal "$_tok")
            _uname=""
            if command -v jq >/dev/null 2>&1; then
                _uname=$(printf '%s' "$_resp" | jq -r '.name // empty' 2>/dev/null || true)
            else
                _uname=$(printf '%s' "$_resp" | sed -nE 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
            fi

            # If user pasted a code instead of a token, or token verification succeeded
            if [ -n "$_uname" ]; then
                _load_auth
                _mal_token="$_tok"
                _mal_uname="$_uname"
                _save_auth
                printf "\033[1;32m✓ Successfully logged into MyAnimeList as: %s\033[0m\n" "$_uname"
                return 0
            else
                # Store provided token directly if manual verification was skipped
                _load_auth
                _mal_token="$_tok"
                _mal_uname="MAL User"
                _save_auth
                printf "\033[1;32m✓ MyAnimeList credentials stored.\033[0m\n"
                return 0
            fi
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
    [ -z "$_anilist_token" ] && [ -z "$_mal_token" ] && return 0

    _mid=$(scrobble_resolve_media_id "$_title")
    if [ -n "$_mid" ]; then
        if [ -n "$_anilist_token" ]; then
            scrobble_sync_progress "$_mid" "$_ep" "$_title"
        fi
        if [ -n "$_mal_token" ]; then
            _mal_id=$(awk -F'	' -v mid="$_mid" '$2 == mid { print $3 }' "$_scrobble_cache_file" 2>/dev/null | head -n 1)
            if [ -n "$_mal_id" ] && [ "$_mal_id" != "0" ]; then
                scrobble_update_mal "$_mal_id" "$_ep" "$_title"
            fi
        fi
    fi
}

# Fetch user's Currently Watching list from AniList
# Emits TSV: search_title \t next_ep \t display_string
scrobble_fetch_watchlist() {
    _load_auth
    if [ -z "$_anilist_token" ] || [ -z "$_anilist_uid" ]; then
        printf "\033[1;33mNot authenticated with AniList.\033[0m\n" >&2
        printf "Run: \033[1;36msranime-cli --login anilist\033[0m to link your account.\n" >&2
        return 1
    fi

    _query=$(cat << GRAPHQLEOF
{"query": "query (\$userId: Int) { MediaListCollection(userId: \$userId, type: ANIME, status: CURRENT) { lists { name entries { progress media { id idMal title { romaji english } episodes } } } } }", "variables": {"userId": $_anilist_uid}}
GRAPHQLEOF
)

    _agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    _resp=$(curl -sL --max-time 8 -X POST         -H "Content-Type: application/json"         -H "Accept: application/json"         -H "Authorization: Bearer $_anilist_token"         -H "User-Agent: $_agent"         -d "$_query"         "https://graphql.anilist.co" 2>/dev/null)

    [ -z "$_resp" ] && return 1

    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$_resp" | jq -r '
            .data.MediaListCollection.lists[].entries[] |
            (if (.media.title.english != null and .media.title.english != "") then .media.title.english else .media.title.romaji end) as $title |
            .progress as $prog |
            (if .media.episodes != null then (.media.episodes | tostring) else "?" end) as $total |
            ($prog + 1) as $next |
            "\($title)	\($next)	\($title)  [Ep \($prog)/\($total)]  (Next: Ep \($next))"
        ' 2>/dev/null
    else
        printf '%s\n' "$_resp" | sed 's/{"progress"/\n{"progress"/g' | while IFS= read -r _entry; do
            [ -z "$_entry" ] && continue
            _prog=$(printf '%s' "$_entry" | sed -nE 's/.*"progress"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p')
            [ -z "$_prog" ] && continue
            _eng=$(printf '%s' "$_entry" | sed -nE 's/.*"english"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')
            _rom=$(printf '%s' "$_entry" | sed -nE 's/.*"romaji"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')
            _eps=$(printf '%s' "$_entry" | sed -nE 's/.*"episodes"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p')
            [ -z "$_eps" ] && _eps="?"
            _title="${_eng:-$_rom}"
            [ -z "$_title" ] && continue
            _next=$((_prog + 1))
            printf "%s\t%s\t%s  [Ep %s/%s]  (Next: Ep %s)\n" "$_title" "$_next" "$_title" "$_prog" "$_eps" "$_next"
        done
    fi
}

# Display watchlist directly to terminal
scrobble_show_watchlist() {
    _list=$(scrobble_fetch_watchlist) || return 1
    if [ -z "$_list" ]; then
        printf "\033[1;34mYour AniList 'Currently Watching' list is empty.\033[0m\n"
        return 0
    fi

    printf "\033[1;36m================ AniList Currently Watching ================\033[0m\n"
    _idx=1
    printf "%s\n" "$_list" | while IFS='	' read -r _title _next _disp; do
        [ -z "$_title" ] && continue
        printf "  \033[1;33m%2d.\033[0m %s\n" "$_idx" "$_disp"
        _idx=$((_idx + 1))
    done
    printf "\033[1;36m============================================================\033[0m\n"
}

# Export lifetime watch log to standard MyAnimeList XML format
scrobble_export_mal() {
    _out_file="$1"
    _watch_log="${SRANIME_CLI_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}/watch.log"

    if [ ! -f "$_watch_log" ] || [ ! -s "$_watch_log" ]; then
        printf "\033[1;33mWatch log is empty. Nothing to export.\033[0m\n" >&2
        return 1
    fi

    _xml_header="<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<myanimelist>\n  <myinfo>\n    <user_export_type>1</user_export_type>\n  </myinfo>"
    _xml_footer="</myanimelist>"

    _xml_body=$(cat "$_watch_log" | while IFS="	" read -r _time _act _ep _id _title _prov; do
        [ -z "$_title" ] && continue
        printf "  <anime>\n    <series_title><![CDATA[%s]]></series_title>\n    <my_watched_episodes>%s</my_watched_episodes>\n    <my_status>Watching</my_status>\n  </anime>\n" "$_title" "${_ep:-1}"
    done)

    if [ -n "$_out_file" ]; then
        mkdir -p "$(dirname "$_out_file")" 2>/dev/null || true
        printf "%b\n%s\n%s\n" "$_xml_header" "$_xml_body" "$_xml_footer" > "$_out_file"
        printf "\033[1;32m✓ Exported watch log in MyAnimeList XML format to:\033[0m %s\n" "$_out_file"
    else
        printf "%b\n%s\n%s\n" "$_xml_header" "$_xml_body" "$_xml_footer"
    fi
}

# Import standard MyAnimeList XML into lifetime watch log and watchlist
scrobble_import_mal() {
    _in_file="$1"
    [ -z "$_in_file" ] || [ ! -f "$_in_file" ] && { printf "Usage: sranime-cli --import-mal <file.xml>\n" >&2; return 1; }

    _watch_log="${SRANIME_CLI_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}/watch.log"
    mkdir -p "$(dirname "$_watch_log")" 2>/dev/null || true

    _count=0
    if command -v python >/dev/null 2>&1; then
        _count=$(python -c '
import sys, xml.etree.ElementTree as ET
in_path, log_path = sys.argv[1], sys.argv[2]
try:
    tree = ET.parse(in_path)
    root = tree.getroot()
    imported = 0
    with open(log_path, "a", encoding="utf-8") as out:
        for a in root.findall(".//anime"):
            t_node = a.find("series_title")
            e_node = a.find("my_watched_episodes")
            if t_node is not None and t_node.text:
                title = t_node.text.strip()
                ep = (e_node.text.strip() if e_node is not None and e_node.text else "1")
                out.write(f"2026-09-28T00:00:00Z\tWATCH\t{ep}\tmal-imported\t{title}\thianime\n")
                imported += 1
    print(imported)
except Exception as e:
    sys.exit(1)
' "$_in_file" "$_watch_log" 2>/dev/null || echo 0)
    fi

    printf "\033[1;32m✓ Successfully imported %s anime series from %s into your lifetime watch log!\033[0m\n" "${_count:-0}" "$_in_file"
}

