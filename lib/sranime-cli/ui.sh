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
