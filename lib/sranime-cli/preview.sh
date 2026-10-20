#!/bin/sh
# sranime-cli preview module — rich terminal UI, metadata cards, and cover art
#
# Provides:
#   - preview_anime <selected_line> : Render metadata card and cover art inside fzf preview pane
#   - format_episodes_with_watched <ep_list> <anime_id> : Append watched badges to episode list
#   - parse_search_cards <html_page> <cache_tsv> : Cache card metadata during search

PREVIEW_CACHE_DIR="${SRANIME_CLI_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/sranime-cli}"
PREVIEW_COVERS_DIR="${PREVIEW_CACHE_DIR}/covers"

_ensure_preview_dirs() {
    [ ! -d "$PREVIEW_CACHE_DIR" ] && mkdir -p "$PREVIEW_CACHE_DIR" 2>/dev/null || true
    [ ! -d "$PREVIEW_COVERS_DIR" ] && mkdir -p "$PREVIEW_COVERS_DIR" 2>/dev/null || true
}

# Parse search page HTML into a fast-lookup TSV file
# Columns: id \t title \t jname \t type \t duration \t sub_eps \t dub_eps \t poster_url \t synopsis
parse_search_cards() {
    _html="$1"
    _out_tsv="$2"
    [ -z "$_html" ] || [ -z "$_out_tsv" ] && return 1

    mkdir -p "$(dirname "$_out_tsv")" 2>/dev/null || true

    # Flatten HTML for regex parsing
    printf "%s\n\n" "$_html" | sed '/id="main-sidebar"/,$d' | tr '\n' ' ' | sed 's|<div class="flw-item|\n<div class="flw-item|g' | while IFS= read -r _item || [ -n "$_item" ]; do
        [ -z "$_item" ] && continue
        printf "%s\n" "$_item" | grep -q 'class="film-detail"' 2>/dev/null || continue

        # Extract Slug / ID
        _id=$(printf "%s" "$_item" | sed -nE 's|.*<h3 class="film-name">[[:space:]]*<a href="[^"]*/([^"/]*)"[[:space:]]*title="([^"]*)".*|\1|p')
        [ -z "$_id" ] && continue

        # Extract Titles
        _title=$(printf "%s" "$_item" | sed -nE 's|.*<h3 class="film-name">[[:space:]]*<a href="[^"]*/([^"/]*)"[[:space:]]*title="([^"]*)".*|\2|p' | sed -e "s|&#039;|'|g" -e 's|&quot;|"|g' -e "s|&amp;|\&|g")
        _jname=$(printf "%s" "$_item" | sed -nE 's|.*data-jname="([^"]*)".*|\1|p' | sed -e "s|&#039;|'|g" -e 's|&quot;|"|g' -e "s|&amp;|\&|g")
        [ -z "$_jname" ] && _jname="$_title"

        # Format / Type & Duration
        _type=$(printf "%s" "$_item" | sed -nE 's|.*<span class="fdi-item">([^<]*)</span>.*|\1|p' | head -n 1)
        [ -z "$_type" ] && _type="Anime"
        _dur=$(printf "%s" "$_item" | sed -nE 's|.*<span class="fdi-item fdi-duration">([^<]*)</span>.*|\1|p')
        [ -z "$_dur" ] && _dur="24m"

        # Sub and Dub episode counts
        _sub=$(printf "%s" "$_item" | sed -nE 's|.*<div class="tick-item tick-sub"[^>]*><i[^>]*></i>([0-9]+)</div>.*|\1|p')
        [ -z "$_sub" ] && _sub="?"
        _dub=$(printf "%s" "$_item" | sed -nE 's|.*<div class="tick-item tick-dub"[^>]*><i[^>]*></i>([0-9]+)</div>.*|\1|p')
        [ -z "$_dub" ] && _dub="0"

        # Poster Image
        _poster=$(printf "%s" "$_item" | sed -nE 's|.*<img [^>]*src="([^"]+)"[^>]*class="film-poster-img".*|\1|p')
        [ -z "$_poster" ] && _poster=$(printf "%s" "$_item" | sed -nE 's|.*data-src="([^"]+)".*|\1|p')
        case "$_poster" in //*) _poster="https:$_poster" ;; esac

        # Description / Synopsis
        _desc=$(printf "%s" "$_item" | sed -nE 's|.*<div class="description"[^>]*>[[:space:]]*([^<]*).*|\1|p' | sed -e "s|&#039;|'|g" -e 's|&quot;|"|g' -e "s|&amp;|\&|g" | tr -d '\r\n')
        [ -z "$_desc" ] && _desc="No synopsis available."

        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$_id" "$_title" "$_jname" "$_type" "$_dur" "$_sub" "$_dub" "$_poster" "$_desc" >> "$_out_tsv"
    done
}

# Render terminal preview for an anime selection
preview_anime() {
    _line="$1"
    [ -z "$_line" ] && return 0

    # Extract ID (handles pure slug, tabbed "id \t title", or full "index \t id \t title")
    if printf "%s" "$_line" | grep -q "	"; then
        _col1=$(printf "%s" "$_line" | cut -f 1 | tr -d "[:space:]")
        case "$_col1" in
            ''|*[!0-9]*) _id="$_col1" ;;
            *) _id=$(printf "%s" "$_line" | cut -f 2) ;;
        esac
    else
        _id=$(printf "%s" "$_line" | sed 's/^[[:space:]]*//; s/[[:space:]].*//')
    fi
    [ -z "$_id" ] && return 0

    _ensure_preview_dirs
    _cache_tsv="${SRANIME_CLI_PREVIEW_TSV:-${PREVIEW_CACHE_DIR}/search_cards.tsv}"

    _title=""
    _jname=""
    _type="TV"
    _dur="24m"
    _sub="?"
    _dub="?"
    _poster=""
    _desc="No synopsis available."

    if [ -f "$_cache_tsv" ]; then
        _row=$(grep "^${_id}	" "$_cache_tsv" 2>/dev/null | head -n 1 || true)
        if [ -n "$_row" ]; then
            _title=$(printf "%s" "$_row" | cut -f 2)
            _jname=$(printf "%s" "$_row" | cut -f 3)
            _type=$(printf "%s" "$_row" | cut -f 4)
            _dur=$(printf "%s" "$_row" | cut -f 5)
            _sub=$(printf "%s" "$_row" | cut -f 6)
            _dub=$(printf "%s" "$_row" | cut -f 7)
            _poster=$(printf "%s" "$_row" | cut -f 8)
            _desc=$(printf "%s" "$_row" | cut -f 9)
        fi
    fi

    # Fallback title if not in cache
    if [ -z "$_title" ]; then
        if printf "%s" "$_line" | grep -q "	"; then
            _col1=$(printf "%s" "$_line" | cut -f 1 | tr -d "[:space:]")
            case "$_col1" in
                ''|*[!0-9]*) _title=$(printf "%s" "$_line" | cut -s -f 2-) ;;
                *) _title=$(printf "%s" "$_line" | cut -s -f 3-) ;;
            esac
        fi
        [ -z "$_title" ] && _title=$(printf "%s" "$_id" | tr '-' ' ')
    fi

    # Check user watch history for this anime
    _hist_file="${SRANIME_CLI_HIST_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}/sranime-hsts"
    _watch_file="${SRANIME_CLI_HIST_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}/watch.log"
    _watched_info="Not started"
    _watched_color="\033[0;90m"

    if [ -f "$_watch_file" ]; then
        _count=$(grep -c "	${_id}	" "$_watch_file" 2>/dev/null || true)
        if [ "${_count:-0}" -gt 0 ]; then
            _last_ep=$(grep "	${_id}	" "$_watch_file" 2>/dev/null | tail -n 1 | cut -f 3 || true)
            _watched_info="✓ In Progress (${_count} eps logged, latest: Ep ${_last_ep})"
            _watched_color="\033[1;32m"
        fi
    elif [ -f "$_hist_file" ]; then
        _last_ep=$(grep "	${_id}	" "$_hist_file" 2>/dev/null | tail -n 1 | cut -f 1 || true)
        if [ -n "$_last_ep" ]; then
            _watched_info="✓ In Progress (Last watched: Ep ${_last_ep})"
            _watched_color="\033[1;32m"
        fi
    fi

    # Render Cover Art if chafa is available and poster URL exists
    if [ -n "$_poster" ] && command -v chafa >/dev/null 2>&1; then
        case "$_poster" in //*) _poster="https:$_poster" ;; esac
        _cover_file="${PREVIEW_COVERS_DIR}/${_id}.jpg"
        if [ ! -s "$_cover_file" ]; then
            curl -sL --max-time 3 -A "Mozilla/5.0" "$_poster" -o "$_cover_file" 2>/dev/null || true
        fi
        if [ -s "$_cover_file" ]; then
            chafa -s 28x14 "$_cover_file" 2>/dev/null || true
            printf "\n"
        fi
    fi

    # Initialize Color Theme
    _lib_dir="${SRANIME_LIB_DIR:-lib/sranime-cli}"
    if [ -f "$_lib_dir/theme_colors.sh" ]; then
        . "$_lib_dir/theme_colors.sh" 2>/dev/null || true
        theme_colors_set "${color_theme:-default}"
    else
        _tc_border="\033[1;36m"
        _tc_title="\033[1;37m"
        _tc_sub="\033[0;35m"
        _tc_label="\033[1;33m"
        _tc_reset="\033[0m"
    fi

    # Render ANSI Metadata Card
    printf "%b====================================================%b\n" "$_tc_border" "$_tc_reset"
    printf "  %b%s%b\n" "$_tc_title" "$_title" "$_tc_reset"
    [ -n "$_jname" ] && [ "$_jname" != "$_title" ] && printf "  %b%s%b\n" "$_tc_sub" "$_jname" "$_tc_reset"
    printf "%b----------------------------------------------------%b\n" "$_tc_border" "$_tc_reset"
    printf "  %bFormat:%b %-8s  %bDuration:%b %s/ep\n" "$_tc_label" "$_tc_reset" "$_type" "$_tc_label" "$_tc_reset" "$_dur"
    printf "  %bEpisodes:%b Sub: \033[1;32m%s\033[0m | Dub: \033[1;34m%s\033[0m\n" "$_tc_label" "$_tc_reset" "$_sub" "$_dub"
    printf "  %bHistory:%b  ${_watched_color}%s\033[0m\n" "$_tc_label" "$_tc_reset" "$_watched_info"
    printf "%b----------------------------------------------------%b\n" "$_tc_border" "$_tc_reset"
    printf "%bSynopsis:%b\n" "$_tc_title" "$_tc_reset"

    # Wrap synopsis nicely
    printf "  %s\n" "$_desc" | fold -s -w 50 2>/dev/null || printf "  %s\n" "$_desc"
    printf "%b====================================================%b\n" "$_tc_border" "$_tc_reset"
}

# Format episode list with watched checkmark badges
# Usage: format_episodes_with_watched <ep_list> <anime_id>
format_episodes_with_watched() {
    _e_list="$1"
    _a_id="$2"
    [ -z "$_e_list" ] && return 0

    _watch_file="${SRANIME_CLI_HIST_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}/watch.log"
    _hist_file="${SRANIME_CLI_HIST_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}/sranime-hsts"

    _watched_eps=""
    if [ -f "$_watch_file" ] && [ -n "$_a_id" ]; then
        _watched_eps=$(grep "	${_a_id}	" "$_watch_file" 2>/dev/null | cut -f 3 | sort -u || true)
    elif [ -f "$_hist_file" ] && [ -n "$_a_id" ]; then
        _watched_eps=$(grep "	${_a_id}	" "$_hist_file" 2>/dev/null | cut -f 1 | sort -u || true)
    fi

    if [ -z "$_watched_eps" ]; then
        printf "%s\n" "$_e_list"
        return 0
    fi

    printf "%s\n" "$_e_list" | while IFS= read -r _ep || [ -n "$_ep" ]; do
        [ -z "$_ep" ] && continue
        if printf "%s\n" "$_watched_eps" | grep -q "^${_ep}$" 2>/dev/null; then
            printf "%s  ✓ [Watched]\n" "$_ep"
        else
            printf "%s\n" "$_ep"
        fi
    done
}
