# bash completion for sranime-cli

_sranime_cli() {
    local cur prev opts qualities providers formats
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="-c --continue -d --download -D --delete --clear-history --show-history -l --logview -s --syncplay -S --select-nth -p --provider --list-providers -q --quality -v --vlc -V --version -h --help -e --episode -r --range --dub --rofi --dmenu --skip --no-detach --exit-after-play -N --nextep-countdown -U --update --edit-config --validate-config --dump-config --watchlist --watchlist-clear -W --watch-log --watch-stats --watch-export --clear-watch-log --no-preview --login --scrobble-status --logout --sync --sync-list --no-scrobble --scrobble --doctor"
    qualities="best worst 360p 480p 720p 1080p"
    providers="hianime allanime gogo"
    formats="json csv"

    case "$prev" in
        -q|--quality)
            COMPREPLY=( $(compgen -W "${qualities}" -- "$cur") )
            return 0
            ;;
        -p|--provider)
            COMPREPLY=( $(compgen -W "${providers}" -- "$cur") )
            return 0
            ;;
        --watch-export)
            COMPREPLY=( $(compgen -W "${formats}" -- "$cur") )
            return 0
            ;;
        -S|--select-nth|-e|--episode|-r|--range)
            return 0
            ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- "$cur") )
        return 0
    fi
}

complete -F _sranime_cli sranime-cli
