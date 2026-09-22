#!/bin/sh
# sranime-cli provider registry
#
# Each provider module exposes three functions:
#   <provider>_search <query>     -> id\tname (per line)
#   <provider>_episodes <id>      -> ep_id\tep_no (per line)
#   <provider>_m3u8 <ep_no> <mode> -> sets: links, sub_link, mal_id, refr
#
# The active provider is selected via $SRANIME_CLI_PROVIDER or defaults to "hianime".

PROVIDERS_DIR="${PROVIDERS_DIR:-$(dirname "$0")/providers}"

load_provider() {
    _provider="${1:-hianime}"
    _provider_file="${PROVIDERS_DIR}/${_provider}.sh"
    if [ -f "$_provider_file" ]; then
        . "$_provider_file"
    else
        [ "$_provider" != "hianime" ] && printf "Warning: provider '%s' not found, falling back to hianime\n" "$_provider" >&2
    fi
}

list_providers() {
    printf "hianime (built-in)\n"
    if [ -d "$PROVIDERS_DIR" ]; then
        for _p in "$PROVIDERS_DIR"/*.sh; do
            [ -f "$_p" ] || continue
            printf "%s\n" "$(basename "$_p" .sh)"
        done
    fi
}
