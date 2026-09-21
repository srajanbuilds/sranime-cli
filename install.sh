#!/bin/sh
set -e

# sranime-cli universal installer
REPO_URL="https://raw.githubusercontent.com/srajanbuilds/sranime-cli/main"

# Color helpers
if [ -t 1 ]; then
    RED="\033[1;31m"
    GREEN="\033[1;32m"
    BLUE="\033[1;34m"
    YELLOW="\033[1;33m"
    RESET="\033[0m"
else
    RED=""
    GREEN=""
    BLUE=""
    YELLOW=""
    RESET=""
fi

info() {
    printf "${BLUE}==>${RESET} %s\n" "$*"
}

success() {
    printf "${GREEN}==>${RESET} %s\n" "$*"
}

warn() {
    printf "${YELLOW}Warning:${RESET} %s\n" "$*"
}

error() {
    printf "${RED}Error:${RESET} %s\n" "$*" >&2
    exit 1
}

# Determine target directories
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

info "Installing sranime-cli to ${BINDIR}..."

mkdir -p "${BINDIR}"
mkdir -p "${MANDIR}"

# Fetch binary
curl -fsSL "${REPO_URL}/sranime-cli" -o "${BINDIR}/sranime-cli" || error "Failed to download sranime-cli script."
chmod +x "${BINDIR}/sranime-cli"

# Fetch man page
curl -fsSL "${REPO_URL}/sranime-cli.1" -o "${MANDIR}/sranime-cli.1" 2>/dev/null || true

# Fetch completions
if [ -n "${BASHDIR}" ]; then
    mkdir -p "${BASHDIR}" 2>/dev/null || true
    curl -fsSL "${REPO_URL}/_sranime-cli-bash" -o "${BASHDIR}/sranime-cli" 2>/dev/null || true
fi

if [ -n "${ZSHDIR}" ]; then
    mkdir -p "${ZSHDIR}" 2>/dev/null || true
    curl -fsSL "${REPO_URL}/_sranime-cli-zsh" -o "${ZSHDIR}/_sranime-cli" 2>/dev/null || true
fi

if [ -n "${FISHDIR}" ]; then
    mkdir -p "${FISHDIR}" 2>/dev/null || true
    curl -fsSL "${REPO_URL}/completions/sranime-cli.fish" -o "${FISHDIR}/sranime-cli.fish" 2>/dev/null || true
fi

success "sranime-cli installed successfully!"

# Check if BINDIR is in PATH
case ":${PATH}:" in
    *:"${BINDIR}":*) ;;
    *)
        warn "${BINDIR} is not in your PATH."
        printf "Add it to your shell configuration file:\n"
        printf "  export PATH=\"%s:\$PATH\"\n\n" "${BINDIR}"
        ;;
esac

# Check dependencies
info "Checking dependencies..."
for dep in fzf mpv curl; do
    if ! command -v "${dep}" >/dev/null 2>&1; then
        warn "Recommended tool '${dep}' is not installed."
    fi
done

printf "\nRun 'sranime-cli --doctor' to inspect your setup.\n"
printf "Enjoy watching anime with sranime-cli!\n"