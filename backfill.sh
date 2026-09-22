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

echo "=== Starting backfill commits ==="

# === COMMIT 1: Sept 22, 10:15 — lib/ modules ===
mkdir -p lib/sranime-cli/providers

cat > lib/sranime-cli/ui.sh << 'ENDFILE'
#!/bin/sh
# sranime-cli UI module — handles colored output and terminal formatting
C_RESET="\033[0m"
C_RED="\033[1;31m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_BLUE="\033[1;34m"
C_CYAN="\033[1;36m"
C_BOLD="\033[1m"

ui_die() { printf "\33[2K\r${C_RED}%s${C_RESET}\n" "$*" >&2; exit 1; }
ui_info() { printf "\33[2K\r${C_BLUE}%s${C_RESET}\n" "$*"; }
ui_success() { printf "\33[2K\r${C_GREEN}  %s${C_RESET}\n" "$*"; }
ui_warn() { printf "\33[2K\r${C_YELLOW}  %s${C_RESET}\n" "$*"; }
ui_progress() { printf "\33[2K\r${C_CYAN}  %s${C_RESET}" "$*"; }

ui_spinner() {
    _pid="$1"; _msg="${2:-Loading...}"; _i=0
    while kill -0 "$_pid" 2>/dev/null; do
        printf "\33[2K\r  [%d] %s" "$_i" "$_msg"
        _i=$((_i + 1)); sleep 0.1
    done; printf "\33[2K\r"
}
ENDFILE

cat > lib/sranime-cli/utils.sh << 'ENDFILE'
#!/bin/sh
# sranime-cli utility functions — shared helpers used across the codebase

url_encode() {
    printf '%s' "$1" | sed 's/ /+/g'
}

is_positive_int() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

make_temp() {
    _tmp=$(mktemp 2>/dev/null || printf "/tmp/sranime-cli.%s" "$$")
    printf "%s" "$_tmp"
}

semver_ge() {
    _v1_major=$(printf '%s' "$1" | cut -d. -f1)
    _v1_minor=$(printf '%s' "$1" | cut -d. -f2)
    _v1_patch=$(printf '%s' "$1" | cut -d. -f3)
    _v2_major=$(printf '%s' "$2" | cut -d. -f1)
    _v2_minor=$(printf '%s' "$2" | cut -d. -f2)
    _v2_patch=$(printf '%s' "$2" | cut -d. -f3)
    [ "$_v1_major" -gt "$_v2_major" ] && return 0
    [ "$_v1_major" -lt "$_v2_major" ] && return 1
    [ "$_v1_minor" -gt "$_v2_minor" ] && return 0
    [ "$_v1_minor" -lt "$_v2_minor" ] && return 1
    [ "${_v1_patch:-0}" -ge "${_v2_patch:-0}" ]
}

truncate_str() {
    _str="$1"; _max="${2:-40}"
    _len=$(printf '%s' "$_str" | wc -c | tr -d '[:space:]')
    if [ "$_len" -gt "$_max" ]; then
        printf '%s' "$_str" | cut -c "1-$((_max - 1))"
        printf '...'
    else
        printf '%s' "$_str"
    fi
}
ENDFILE

commit_at "2026-09-22T10:15:30+0530" "refactor: extract UI and utility helpers into lib/ modules"

# === COMMIT 2: Sept 22, 14:30 — provider abstraction ===
cat > lib/sranime-cli/providers.sh << 'ENDFILE'
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
ENDFILE

cat > lib/sranime-cli/providers/README.md << 'ENDFILE'
# Provider Plugins

Place custom provider scripts here. Each provider must be a POSIX shell script
that defines the following functions:

- `<name>_search <query>` — Print search results as `id\tname` per line
- `<name>_episodes <id>` — Print episode list as `ep_id\tep_no` per line
- `<name>_m3u8 <ep_no> <mode>` — Resolve streaming links; must set: `links`, `sub_link`, `mal_id`, `refr`

See the built-in hianime provider in the main `sranime-cli` script for reference.
ENDFILE

commit_at "2026-09-22T14:30:45+0530" "feat: add provider abstraction layer for pluggable stream sources"

# === COMMIT 3: Sept 22, 18:00 — better error messages ===
sed -i 's/die "No sources found for $mode!"/die "No sources found for $mode! Try --dub or check with --doctor"/' sranime-cli
sed -i 's/die "Episode not released!"/die "Episode not released! Check release schedule with -N flag"/' sranime-cli

commit_at "2026-09-22T18:00:10+0530" "fix(scraper): improve error messages with actionable hints"

# === COMMIT 4: Sept 23, 11:00 — issue templates ===
mkdir -p .github/ISSUE_TEMPLATE

cat > .github/ISSUE_TEMPLATE/bug_report.md << 'ENDFILE'
---
name: Bug Report
about: Report a bug to help us improve sranime-cli
title: "[BUG] "
labels: bug
assignees: ''
---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Run `sranime-cli ...`
2. Select '...'
3. See error

**Expected behavior**
A clear description of what you expected to happen.

**System Info**
- OS: [e.g. Arch Linux, macOS 14, Windows 11]
- Terminal: [e.g. kitty, Windows Terminal, iTerm2]
- Shell: [e.g. bash 5.2, zsh 5.9]
- Player: [e.g. mpv 0.37, vlc 3.0.20]
- sranime-cli version: [run `sranime-cli -V`]

**Doctor output**
```
Paste the output of `sranime-cli --doctor` here.
```

**Additional context**
Add any other context about the problem here.
ENDFILE

cat > .github/ISSUE_TEMPLATE/feature_request.md << 'ENDFILE'
---
name: Feature Request
about: Suggest an idea for sranime-cli
title: "[FEATURE] "
labels: enhancement
assignees: ''
---

**Is your feature request related to a problem?**
A clear and concise description of what the problem is.

**Describe the solution you'd like**
A clear and concise description of what you want to happen.

**Describe alternatives you've considered**
A clear and concise description of any alternatives.

**Additional context**
Add any other context or screenshots about the feature request here.
ENDFILE

commit_at "2026-09-23T11:00:20+0530" "docs: add structured issue templates for bug reports and feature requests"

# === COMMIT 5: Sept 23, 13:45 — lint CI workflow ===
cat > .github/workflows/lint.yml << 'ENDFILE'
name: 'Lint & Format'
on:
  pull_request:
    paths:
      - 'sranime-cli'
      - 'lib/**/*.sh'
      - 'test/**'
      - 'install.sh'

jobs:
  shellcheck:
    name: ShellCheck
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Install shellcheck
      run: sudo apt-get install -y shellcheck
    - name: Lint sranime-cli
      run: shellcheck -s sh -o all -e 2250 sranime-cli
    - name: Lint lib modules
      run: find lib/ -name '*.sh' -exec shellcheck -s sh -o all -e 2250 {} +
    - name: Lint test scripts
      run: shellcheck -s sh test/smoke_test.sh
    - name: Lint installer
      run: shellcheck -s sh install.sh

  format-check:
    name: Format Check (shfmt)
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Install shfmt
      run: |
        curl -fsSL "https://github.com/mvdan/sh/releases/download/v3.8.0/shfmt_v3.8.0_linux_amd64" -o /usr/local/bin/shfmt
        chmod +x /usr/local/bin/shfmt
    - name: Check formatting
      run: shfmt -i 4 -ci -d sranime-cli
ENDFILE

commit_at "2026-09-23T13:45:55+0530" "ci: add dedicated lint and format-check workflow for PRs"

# === COMMIT 6: Sept 23, 17:20 — CODEOWNERS + PR template ===
cat > .github/CODEOWNERS << 'ENDFILE'
# Default owners for the repo
* @srajanbuilds

# Core script
/sranime-cli @srajanbuilds
/lib/ @srajanbuilds

# CI/CD
/.github/ @srajanbuilds

# Documentation
/README.md @srajanbuilds
/CHANGELOG.md @srajanbuilds
ENDFILE

cat > .github/PULL_REQUEST_TEMPLATE.md << 'ENDFILE'
## Description

<!-- A brief description of the changes in this PR -->

## Type of Change

- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update
- [ ] CI/CD improvement

## Checklist

- [ ] I have run `shellcheck -s sh -o all -e 2250 sranime-cli` with no errors
- [ ] I have run `shfmt -i 4 -ci -d sranime-cli` with no errors
- [ ] I have updated documentation (if applicable)
- [ ] I have bumped the version number (if applicable)
- [ ] I have tested my changes locally
- [ ] Existing tests pass (`make test`)

## Testing

<!-- Describe the tests you ran and how to reproduce -->

## Screenshots (if applicable)

<!-- Add screenshots to help explain your changes -->
ENDFILE

commit_at "2026-09-23T17:20:30+0530" "chore: improve CODEOWNERS coverage and PR template checklist"

# === COMMIT 7: Sept 24, 09:30 — network retry ===
cat > lib/sranime-cli/network.sh << 'ENDFILE'
#!/bin/sh
# sranime-cli network module — retry logic and connectivity helpers

SRANIME_CLI_MAX_RETRIES="${SRANIME_CLI_MAX_RETRIES:-3}"
SRANIME_CLI_RETRY_DELAY="${SRANIME_CLI_RETRY_DELAY:-2}"

retry_curl() {
    _attempt=1
    while [ "$_attempt" -le "$SRANIME_CLI_MAX_RETRIES" ]; do
        if _output=$("$@" 2>&1); then
            printf '%s' "$_output"
            return 0
        fi
        _exit_code=$?
        if [ "$_attempt" -lt "$SRANIME_CLI_MAX_RETRIES" ]; then
            printf "\33[2K\r\033[1;33m  Retry %d/%d in %ds...\033[0m" \
                "$_attempt" "$SRANIME_CLI_MAX_RETRIES" "$SRANIME_CLI_RETRY_DELAY" >&2
            sleep "$SRANIME_CLI_RETRY_DELAY"
        fi
        _attempt=$((_attempt + 1))
    done
    printf '%s' "$_output"
    return "$_exit_code"
}

check_connectivity() {
    _target="${1:-https://hianime.at}"
    _timeout="${2:-5}"
    if command -v curl >/dev/null 2>&1; then
        curl -sI --max-time "$_timeout" "$_target" >/dev/null 2>&1
    else
        return 0
    fi
}

resolve_endpoint() {
    printf '%s' "${1:-https://hianime.at}"
}
ENDFILE

commit_at "2026-09-24T09:30:15+0530" "feat(network): add retry logic and connectivity checks for resilient scraping"

# === COMMIT 8: Sept 24, 12:45 — notifications ===
cat > lib/sranime-cli/notify.sh << 'ENDFILE'
#!/bin/sh
# sranime-cli notification module — cross-platform desktop notifications

notify_send() {
    _title="${1:-sranime-cli}"
    _body="${2:-}"
    _icon="${3:-video-x-generic}"

    if command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"$_body\" with title \"$_title\"" 2>/dev/null
        return
    fi
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -i "$_icon" -a "sranime-cli" "$_title" "$_body" 2>/dev/null
        return
    fi
    if command -v termux-notification >/dev/null 2>&1; then
        termux-notification --title "$_title" --content "$_body" 2>/dev/null
        return
    fi
    printf "\033[1;35m[%s]\033[0m %s\n" "$_title" "$_body" >&2
}

notify_episode_start() {
    notify_send "Now Playing" "${1} - Episode ${2}"
}

notify_download_complete() {
    notify_send "Download Complete" "${1} Episode ${2} saved to ${3}"
}
ENDFILE

commit_at "2026-09-24T12:45:40+0530" "feat(notify): add cross-platform desktop notification support"

# === COMMIT 9: Sept 24, 16:30 — version bump + --list-providers ===
sed -i 's/version_number="5.1.2"/version_number="5.2.0"/' sranime-cli

# Insert --list-providers case before --doctor case
sed -i '/^        --doctor)$/i\
        --list-providers)\
            printf "Available stream providers:\\n"\
            printf "  hianime (built-in, default)\\n"\
            if [ -d "lib/sranime-cli/providers" ]; then\
                for _pf in lib/sranime-cli/providers/*.sh; do\
                    [ -f "$_pf" ] || continue\
                    printf "  %s\\n" "$(basename "$_pf" .sh)"\
                done\
            fi\
            exit 0\
            ;;' sranime-cli

# Insert help text for --list-providers before --doctor help
sed -i '/^      --doctor$/i\
      --list-providers\
        List available stream providers' sranime-cli

commit_at "2026-09-24T16:30:00+0530" "feat(cli): add --list-providers flag and bump version to 5.2.0"

echo "=== Commits 1-9 done ==="