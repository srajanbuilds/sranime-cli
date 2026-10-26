#!/bin/sh
# lib/sranime-cli/subtitles.sh - Multi-Language Subtitles & Audio Track Subsystem
# Standardized subtitle and audio track selection and extraction for sranime-cli.

# Normalize language names or codes to standard ISO 639-1 / 639-2 codes
subtitles_normalize_lang() {
    case "$1" in
        [eE][nN]|[eE][nN][gG]|[eE][nN][gG][lL][iI][sS][hH]) printf "en" ;;
        [eE][sS]|[sS][pP][aA]|[sS][pP][aA][nN][iI][sS][hH]|español|espanol|[eE][sS][pP][aA]ñol) printf "es" ;;
        [fF][rR]|[fF][rR][aA]|[fF][rR][eE]|[fF][rR][eE][nN][cC][hH]|français|francais) printf "fr" ;;
        [dD][eE]|[dD][eE][uU]|[gG][eE][rR]|[gG][eE][rR][mM][aA][nN]|[dD][eE][uU][tT][sS][cC][hH]) printf "de" ;;
        [iI][tT]|[iI][tT][aA]|[iI][tT][aA][lL][iI][aA][nN]|[iI][tT][aA][lL][iI][aA][nN][oO]) printf "it" ;;
        [pP][tT]|[pP][oO][rR]|[pP][oO][rR][tT][uU][gG][uU][eE][sS][eE]|português|portugues) printf "pt" ;;
        [aA][rR]|[aA][rR][aA]|[aA][rR][aA][bB][iI][cC]|العربية) printf "ar" ;;
        [rR][uU]|[rR][uU][sS]|[rR][uU][sS][sS][iI][aA][nN]|русский) printf "ru" ;;
        [jJ][aA]|[jJ][pP]|[jJ][pP][nN]|[jJ][aA][pP][aA][nN][eE][sS][eE]|日本語) printf "ja" ;;
        [zZ][hH]|[zZ][hH][oO]|[cC][hH][iI]|[cC][hH][iI][nN][eE][sS][eE]|中文) printf "zh" ;;
        [kK][oO]|[kK][oO][rR]|[kK][oO][rR][eE][aA][nN]|한국어) printf "ko" ;;
        [hH][iI]|[hH][iI][nN]|[hH][iI][nN][dD][iI]|हिन्दी) printf "hi" ;;
        [iI][dD]|[iI][nN][dD]|[iI][nN][dD][oO][nN][eE][sS][iI][aA][nN]|bahasa) printf "id" ;;
        *)
            _raw=$(printf "%s" "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
            printf "%s" "$_raw"
            ;;
    esac
}

# Parse all available subtitle tracks from provider JSON string
# Format output: lang \t src_url \t is_default
subtitles_list_tracks_json() {
    _json="$1"
    [ -z "$_json" ] && return 1

    (printf "%s" "$_json" | sed 's|.*"subtitles":\[||; s|\].*||; s|},{|\n{|g'; printf "\n") | while IFS= read -r _item || [ -n "$_item" ]; do
        [ -z "$_item" ] && continue
        case "$_item" in
            *'"lang":'*'"src":'*)
                _lang="${_item#*\"lang\":\"}"
                _lang="${_lang%%\"*}"
                _src="${_item#*\"src\":\"}"
                _src="${_src%%\"*}"
                _def="0"
                case "$_item" in *'"default":true'*) _def="1" ;; esac
                if [ -n "$_lang" ] && [ -n "$_src" ]; then
                    printf "%s\t%s\t%s\n" "$_lang" "$_src" "$_def"
                fi
                ;;
        esac
    done
}

# Extract specific subtitle URL matching requested language from provider JSON
# Fallbacks: requested lang -> default track -> first track
subtitles_extract_from_json() {
    _json="$1"
    _req_lang=$(subtitles_normalize_lang "${2:-en}")
    [ -z "$_json" ] && return 1

    _tracks=$(subtitles_list_tracks_json "$_json")
    [ -z "$_tracks" ] && return 1

    # 1. Match requested normalized language
    _match=$(printf "%s\n" "$_tracks" | while IFS="$(printf '\t')" read -r _l _s _d; do
        _norm_l=$(subtitles_normalize_lang "$_l")
        if [ "$_norm_l" = "$_req_lang" ]; then
            printf "%s" "$_s"
            break
        fi
    done)

    # 2. Fallback to default track if match not found
    if [ -z "$_match" ]; then
        _match=$(printf "%s\n" "$_tracks" | sed -n '/\t1$/{s|.*\t\(http[^\t]*\)\t1$|\1|p;q}')
        [ -z "$_match" ] && _match=$(printf "%s\n" "$_tracks" | grep -m 1 $'\t1$' | cut -f2)
    fi

    # 3. Fallback to first track
    if [ -z "$_match" ]; then
        _match=$(printf "%s\n" "$_tracks" | head -n 1 | cut -f2)
    fi

    printf "%s" "$_match"
}

# Generate player-specific command line arguments for subtitle and audio language
subtitles_get_player_args() {
    _player="${1:-mpv}"
    _sub_lang="$2"
    _audio_lang="$3"
    _sub_file="$4"
    _args=""

    _norm_sub=""
    _norm_audio=""
    [ -n "$_sub_lang" ] && _norm_sub=$(subtitles_normalize_lang "$_sub_lang")
    [ -n "$_audio_lang" ] && _norm_audio=$(subtitles_normalize_lang "$_audio_lang")

    case "$_player" in
        *mpv*|*syncplay*)
            [ -n "$_norm_sub" ] && _args="$_args --slang=$_norm_sub,en"
            [ -n "$_norm_audio" ] && _args="$_args --alang=$_norm_audio,ja,en"
            [ -n "$_sub_file" ] && _args="$_args --sub-file=$_sub_file"
            ;;
        *iina*)
            [ -n "$_norm_sub" ] && _args="$_args --mpv-slang=$_norm_sub,en"
            [ -n "$_norm_audio" ] && _args="$_args --mpv-alang=$_norm_audio,ja,en"
            if [ -n "$_sub_file" ]; then
                _sub_esc=$(printf "%s" "$_sub_file" | sed 's|:|\\:|g')
                _args="$_args --mpv-sub-files=$_sub_esc"
            fi
            ;;
        *vlc*)
            [ -n "$_norm_sub" ] && _args="$_args --sub-language=$_norm_sub"
            [ -n "$_norm_audio" ] && _args="$_args --audio-language=$_norm_audio"
            [ -n "$_sub_file" ] && _args="$_args :input-slave=$_sub_file"
            ;;
        *)
            [ -n "$_sub_file" ] && _args="$_args --sub-file=$_sub_file"
            ;;
    esac

    # Trim leading space
    printf "%s" "$_args" | sed 's|^ ||'
}

# Download subtitle sidecar file to destination
subtitles_download_sidecar() {
    _sub_url="$1"
    _dest_file="$2"
    _referer="${3:-}"
    _user_agent="${4:-Mozilla/5.0}"
    [ -z "$_sub_url" ] || [ -z "$_dest_file" ] && return 1

    _parent_dir=$(dirname "$_dest_file")
    [ ! -d "$_parent_dir" ] && mkdir -p "$_parent_dir" 2>/dev/null || true

    curl -sL -A "$_user_agent" ${referer:+-e "$_referer"} --max-time 15 "$_sub_url" -o "$_dest_file" 2>/dev/null
    [ -f "$_dest_file" ] && [ -s "$_dest_file" ]
}
