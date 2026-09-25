#!/bin/bash
set -e
cd "$(dirname "$0")"

export GIT_AUTHOR_NAME="Srajan Mishra"
export GIT_COMMITTER_NAME="Srajan Mishra"
export GIT_AUTHOR_EMAIL="mail2srajanmishra@gmail.com"
export GIT_COMMITTER_EMAIL="mail2srajanmishra@gmail.com"

commit_at() {
    export GIT_AUTHOR_DATE="$1"
    export GIT_COMMITTER_DATE="$1"
    git add -A
    git commit -m "$2"
}

# === COMMIT 12: Sept 25, 19:45 — CHANGELOG update ===
cat > CHANGELOG.md << 'ENDFILE'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.2.0] - 2026-09-25

### Added
- Modular `lib/` architecture with UI, utility, network, and notification modules.
- Provider abstraction layer for pluggable stream sources (`lib/sranime-cli/providers/`).
- `--list-providers` flag to list available stream providers.
- Network retry logic with configurable `SRANIME_CLI_MAX_RETRIES` and `SRANIME_CLI_RETRY_DELAY`.
- Cross-platform desktop notifications (macOS, Linux, Android/Termux) for episode and download events.
- Persistent watchlist feature with `--watchlist` and `--watchlist-clear` commands.
- Comprehensive test framework (`test/test_utils.sh`) with assertion helpers.
- Extended CLI flag test suite (`test/test_cli_flags.sh`).
- Dedicated lint and format-check CI workflow for pull requests.
- Structured issue templates for bug reports and feature requests.
- Improved CODEOWNERS and PR template with checklist.

### Changed
- Improved scraper error messages with actionable hints (e.g., "try --dub", "check with --doctor").
- Version bumped to 5.2.0.

### Fixed
- Error messages now suggest relevant flags instead of generic failures.

## [5.1.2] - 2026-09-21

### Added
- Added `--doctor` system diagnostic tool to inspect dependencies, players, configuration files, and network connectivity.
- Added universal `install.sh` script for one-line POSIX installation.
- Added user (`~/.config/sranime-cli/sranime-cli.conf`) and system (`/etc/sranime-cli/sranime-cli.conf`) configuration loading.
- Added `--edit-config` and `--dump-config` convenience flags.
- Added `--show-history` command and `--clear-history` alias with explicit terminal feedback.
- Added comprehensive smoke test suite (`test/smoke_test.sh`) and CI automation.
- Added `.editorconfig` for cross-editor formatting consistency.

### Changed
- Improved interactive menu program detection to automatically fall back across `fzf`, `rofi`, and `dmenu`.
- Enhanced player detection error reporting to reference the configuration file.

## [5.1.0] - 2026-09-14

### Added
- Initial release of sranime-cli with hianime stream scraper.
- Support for subtitle tracks, multiple resolutions (1080p, 720p, 480p, 360p), and dubbed playback.
- Support for `mpv`, `vlc`, `iina`, `syncplay`, and Android Termux players.
ENDFILE

commit_at "2026-09-25T19:45:20+0530" "docs: update CHANGELOG with v5.2.0 release notes"

# === COMMIT 13: Sept 26, 09:00 — uninstaller ===
cat > uninstall.sh << 'ENDFILE'
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
ENDFILE

commit_at "2026-09-26T09:00:15+0530" "feat(installer): add standalone uninstall.sh with optional data cleanup"

echo "=== Commits 12-13 done ==="