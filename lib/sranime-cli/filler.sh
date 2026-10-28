#!/bin/sh
# sranime-cli Smart Filler Episode Badges & Skipping Engine
#
# Classifies episodes into:
#   - Manga Canon   ([1;32m[Canon][0m)
#   - Anime Canon   ([1;36m[Anime Canon][0m)
#   - Mixed Canon   ([1;33m[Mixed][0m)
#   - Filler        ([1;31m[Filler][0m)
#
# Provides:
#   - filler_slugify <title>
#   - filler_get_episode_status <anime_title> <ep_no>
#   - filler_format_badge <status>
#   - filler_enrich_episode_list <ep_list> <anime_title> [canon_only]
#   - filler_is_filler <anime_title> <ep_no>
#   - filler_find_next_canon <anime_title> <current_ep> <ep_list>

_filler_cache_dir="${SRANIME_CLI_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/sranime-cli}/filler"

_ensure_filler_cache() {
    [ ! -d "$_filler_cache_dir" ] && mkdir -p "$_filler_cache_dir" 2>/dev/null || true
}

# Convert show title into lookup slug (e.g. "Naruto: Shippuden" -> "naruto-shippuden")
filler_slugify() {
    _raw="$1"
    printf '%s' "$_raw" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//'
}

# Fast built-in offline classification for major series
_filler_builtin_check() {
    _slug="$1"
    _ep="$2"
    _ep_num=$(printf "%s" "$_ep" | grep -o '^[0-9]\+' || echo 0)

    case "$_slug" in
        naruto)
            # Naruto Original: 1-220
            # Fillers: 26, 97, 101-106, 136-219
            if [ "$_ep_num" -eq 26 ] || [ "$_ep_num" -eq 97 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 101 ] && [ "$_ep_num" -le 106 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 136 ] && [ "$_ep_num" -le 219 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -eq 220 ]; then echo "MIXED_CANON"; return 0; fi
            echo "MANGA_CANON"; return 0
            ;;
        naruto-shippuden)
            # Naruto Shippuden: 1-500
            # Major fillers: 57-71, 91-112, 144-151, 170-171, 176-196, 223-242, 257-260, 279-281, 284-295, 303-320, 347-361, 376-377, 388-390, 394-413, 416-417, 422-423, 427-450, 464-468, 480-483
            if [ "$_ep_num" -ge 57 ] && [ "$_ep_num" -le 71 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 91 ] && [ "$_ep_num" -le 112 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 144 ] && [ "$_ep_num" -le 151 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 176 ] && [ "$_ep_num" -le 196 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 223 ] && [ "$_ep_num" -le 242 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 303 ] && [ "$_ep_num" -le 320 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 347 ] && [ "$_ep_num" -le 361 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 394 ] && [ "$_ep_num" -le 413 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 427 ] && [ "$_ep_num" -le 450 ]; then echo "FILLER"; return 0; fi
            echo "MANGA_CANON"; return 0
            ;;
        bleach)
            # Bleach: 1-366
            # Bount Arc: 64-108, Stolen Hogyoku: 128-137, Captain Amagai: 168-189, Zanpakuto Rebellion: 230-265, Gotei 13 Invading Army: 317-342
            if [ "$_ep_num" -ge 64 ] && [ "$_ep_num" -le 108 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 128 ] && [ "$_ep_num" -le 137 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 168 ] && [ "$_ep_num" -le 189 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 230 ] && [ "$_ep_num" -le 265 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 317 ] && [ "$_ep_num" -le 342 ]; then echo "FILLER"; return 0; fi
            echo "MANGA_CANON"; return 0
            ;;
        one-piece)
            # One Piece Fillers: 54-61, 98-99, 102, 131-143, 196-206 (G-8), 220-226, 326-335, 382-384, 426-429, 575-578, 626-628, 747-750, 780-782, 895-896, 1029-1030
            if [ "$_ep_num" -ge 54 ] && [ "$_ep_num" -le 61 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 131 ] && [ "$_ep_num" -le 143 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 196 ] && [ "$_ep_num" -le 206 ]; then echo "ANIME_CANON"; return 0; fi
            if [ "$_ep_num" -ge 220 ] && [ "$_ep_num" -le 226 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 326 ] && [ "$_ep_num" -le 335 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 426 ] && [ "$_ep_num" -le 429 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 575 ] && [ "$_ep_num" -le 578 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 780 ] && [ "$_ep_num" -le 782 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 895 ] && [ "$_ep_num" -le 896 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 1029 ] && [ "$_ep_num" -le 1030 ]; then echo "FILLER"; return 0; fi
            echo "MANGA_CANON"; return 0
            ;;
        boruto-naruto-next-generations|boruto)
            if [ "$_ep_num" -eq 16 ] || [ "$_ep_num" -eq 17 ] || [ "$_ep_num" -eq 40 ] || [ "$_ep_num" -eq 41 ] || [ "$_ep_num" -eq 49 ] || [ "$_ep_num" -eq 50 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 67 ] && [ "$_ep_num" -le 69 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 112 ] && [ "$_ep_num" -le 119 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 138 ] && [ "$_ep_num" -le 140 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 152 ] && [ "$_ep_num" -le 156 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 231 ] && [ "$_ep_num" -le 232 ]; then echo "FILLER"; return 0; fi
            if [ "$_ep_num" -ge 256 ] && [ "$_ep_num" -le 258 ]; then echo "FILLER"; return 0; fi
            echo "ANIME_CANON"; return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Determine status for an anime episode
filler_get_episode_status() {
    _title="$1"
    _ep="$2"
    _slug="${3:-$(filler_slugify "$_title")}"

    # 1. Builtin database check
    _builtin=$(_filler_builtin_check "$_slug" "$_ep" 2>/dev/null || true)
    if [ -n "$_builtin" ]; then
        printf "%s" "$_builtin"
        return 0
    fi

    # 2. Cached lookup file check
    _ensure_filler_cache
    _cache_file="$_filler_cache_dir/${_slug}.tsv"
    if [ -f "$_cache_file" ]; then
        _cached_status=$(grep -w "^${_ep}" "$_cache_file" 2>/dev/null | cut -f2 || true)
        if [ -n "$_cached_status" ]; then
            printf "%s" "$_cached_status"
            return 0
        fi
    fi

    # Default fallback for unlisted anime
    printf "MANGA_CANON"
}

# Format ANSI classification badge
filler_format_badge() {
    _status="$1"
    case "$_status" in
        FILLER)
            printf " [1;31m[Filler][0m"
            ;;
        MIXED_CANON)
            printf " [1;33m[Mixed][0m"
            ;;
        ANIME_CANON)
            printf " [1;36m[Anime Canon][0m"
            ;;
        MANGA_CANON|*)
            printf " [1;32m[Canon][0m"
            ;;
    esac
}

# Check if an episode is non-canon filler (0 = filler, 1 = not filler)
filler_is_filler() {
    _title="$1"
    _ep="$2"
    _status=$(filler_get_episode_status "$_title" "$_ep")
    [ "$_status" = "FILLER" ] && return 0
    return 1
}

# Enrich raw episode list with classification badges
# Supports canon_only flag to suppress filler rows entirely
filler_enrich_episode_list() {
    _ep_list="$1"
    _anime_title="$2"
    _canon_only="${3:-0}"

    [ -z "$_ep_list" ] && return 1
    _slug=$(filler_slugify "$_anime_title")

    printf "%s\n" "$_ep_list" | while IFS= read -r _ep || [ -n "$_ep" ]; do
        [ -z "$_ep" ] && continue
        _status=$(filler_get_episode_status "$_anime_title" "$_ep" "$_slug")
        
        # If canon-only mode is active, skip filler episodes completely
        if [ "$_canon_only" = "1" ] && [ "$_status" = "FILLER" ]; then
            continue
        fi

        _badge=$(filler_format_badge "$_status")
        printf "%s\tEpisode %s%s\n" "$_ep" "$_ep" "$_badge"
    done
}

# Find the next canon episode number in the list after current_ep
filler_find_next_canon() {
    _title="$1"
    _curr_ep="$2"
    _ep_list="$3"

    _found_curr=0
    _next_canon=""

    for _ep in $_ep_list; do
        if [ "$_found_curr" = "0" ]; then
            if [ "$_ep" = "$_curr_ep" ]; then
                _found_curr=1
            fi
            continue
        fi

        if ! filler_is_filler "$_title" "$_ep"; then
            _next_canon="$_ep"
            break
        fi
    done

    printf "%s" "$_next_canon"
}
