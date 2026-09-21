# bash completion for sranime-cli

_sranime_cli() {
    local cur prev opts qualities
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="-c --continue -d --download -D --delete -l --logview -s --syncplay -S --select-nth -q --quality -v --vlc -V --version -h --help -e --episode -r --range --dub --rofi --dmenu --skip --no-detach --exit-after-play -N --nextep-countdown -U --update --edit-config --dump-config"
    qualities="best worst 360p 480p 720p 1080p"

    case "$prev" in
        -q|--quality)
            COMPREPLY=( $(compgen -W "${qualities}" -- "$cur") )
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
