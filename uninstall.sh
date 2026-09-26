#!/bin/sh
set -e

# sranime-cli uninstaller

if [ -t 1 ]; then
    RED="\033[1;31m"; GREEN="\033[1;32m"; BLUE="\033[1;34m"
    YELLOW="\033[1;33m"; RESET="\033[0m"
else
    RED=""; GREEN=""; BLUE=""; YELLOW=""; RESET=""
fi

info() { printf "${BLUE}==> ${RESET}%s\n" "$*"; }
success() { printf "${GREEN}==> ${RESET}%s\n" "$*"; }
warn() { printf "${YELLOW}Warning:${RESET} %s\n" "$*"; }

if [ "$(id -u)" -eq 0 ]; then
    BINDIR="/usr/local/bin"
    MANDIR="/usr/local/share/man/man1"
    BASHDIR="/usr/local/share/bash-completion/completions"
    ZSHDIR="/usr/local/share/zsh/site-functions"
else
    BINDIR="${HOME}/.local/bin"
    MANDIR="${HOME}/.local/share/man/man1"
    BASHDIR="${HOME}/.local/share/bash-completion/completions"
    ZSHDIR="${HOME}/.local/share/zsh/site-functions"
    FISHDIR="${XDG_CONFIG_HOME:-${HOME}/.config}/fish/completions"
fi

info "Uninstalling sranime-cli..."

_removed=0
_try_remove() {
    if [ -f "$1" ]; then
        rm -f "$1"
        printf "  Removed: %s\n" "$1"
        _removed=$((_removed + 1))
    fi
}

_try_remove "${BINDIR}/sranime-cli"
_try_remove "${MANDIR}/sranime-cli.1"
_try_remove "${BASHDIR}/sranime-cli"
_try_remove "${ZSHDIR}/_sranime-cli"
[ -n "${FISHDIR}" ] && _try_remove "${FISHDIR}/sranime-cli.fish"

if [ "$_removed" -eq 0 ]; then
    warn "No sranime-cli files found to remove."
else
    success "sranime-cli uninstalled ($_removed files removed)."
fi

_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sranime-cli"
_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli"

if [ -d "$_config_dir" ] || [ -d "$_state_dir" ]; then
    printf "\nData directories found:\n"
    [ -d "$_config_dir" ] && printf "  Config: %s\n" "$_config_dir"
    [ -d "$_state_dir" ] && printf "  State:  %s\n" "$_state_dir"
    printf "Remove these? [y/N] "
    read -r _answer
    case "$_answer" in
        [Yy]*)
            [ -d "$_config_dir" ] && rm -rf "$_config_dir" && printf "  Removed config directory\n"
            [ -d "$_state_dir" ] && rm -rf "$_state_dir" && printf "  Removed state directory\n"
            ;;
        *) printf "  Keeping data directories.\n" ;;
    esac
fi

printf "\nDone.\n"
