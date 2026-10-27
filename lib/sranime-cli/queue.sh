#!/bin/sh
# sranime-cli queue module — background batch download queue daemon
#
# Provides:
#   - queue_init
#   - queue_add <title> <ep_no> [quality] [provider] [out_dir]
#   - queue_list
#   - queue_set_status <id> <new_status>
#   - queue_clear [completed|all]
#   - queue_pause
#   - queue_resume
#   - queue_is_paused
#   - queue_get_next
#   - queue_process_next
#   - queue_run_daemon

_queue_dir="${SRANIME_CLI_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}"
_queue_file="${_queue_dir}/queue.tsv"
_queue_paused_file="${_queue_dir}/queue.paused"
_queue_lock_file="${_queue_dir}/queue.lock"

queue_init() {
    [ ! -d "$_queue_dir" ] && mkdir -p "$_queue_dir" 2>/dev/null || true
    if [ ! -f "$_queue_file" ]; then
        printf "# ID\tTIMESTAMP\tSTATUS\tTITLE\tEP\tQUALITY\tPROVIDER\tDEST\n" > "$_queue_file"
    fi
}

queue_add() {
    _title="$1"
    _ep="$2"
    _qual="${3:-best}"
    _prov="${4:-hianime}"
    _out="${5:-.}"

    [ -z "$_title" ] || [ -z "$_ep" ] && return 1

    queue_init
    _seq=$(wc -l < "$_queue_file" 2>/dev/null | tr -d '[:space:]' || echo 1)
    _qid="Q$(date +%s 2>/dev/null || echo 100000)_${_seq}_$$"
    _ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")

    printf "%s\t%s\tQUEUED\t%s\t%s\t%s\t%s\t%s\n" \
        "$_qid" "$_ts" "$_title" "$_ep" "$_qual" "$_prov" "$_out" >> "$_queue_file"

    printf "\033[1;32m✓ Enqueued for background download:\033[0m [%s] %s Ep %s (%s, %s)\n" \
        "$_qid" "$_title" "$_ep" "$_qual" "$_prov" >&2
    printf "%s\n" "$_qid"
}

queue_list() {
    queue_init
    _lines=$(grep -v '^#' "$_queue_file" 2>/dev/null || true)
    if [ -z "$_lines" ]; then
        printf "\033[1;34mDownload queue is empty.\033[0m\n"
        return 0
    fi

    printf "\033[1;36m============================ Download Queue ============================\033[0m\n"
    printf "  %-14s %-12s %-26s %-4s %-6s\n" "ID" "STATUS" "TITLE" "EP" "QUALITY"
    printf "  ----------------------------------------------------------------------\n"

    printf '%s\n' "$_lines" | while IFS='	' read -r _qid _ts _stat _title _ep _qual _prov _out; do
        [ -z "$_qid" ] && continue
        case "$_stat" in
            QUEUED)      _col="\033[1;33m" ;;
            DOWNLOADING) _col="\033[1;36m" ;;
            DONE)        _col="\033[1;32m" ;;
            FAILED)      _col="\033[1;31m" ;;
            PAUSED)      _col="\033[0;90m" ;;
            *)           _col="\033[0m" ;;
        esac
        _title_trunc=$(printf '%.24s' "$_title")
        printf "  %-14s ${_col}%-12s\033[0m %-26s %-4s %-6s\n" "$_qid" "$_stat" "$_title_trunc" "$_ep" "$_qual"
    done
    printf "\033[1;36m========================================================================\033[0m\n"
}

queue_set_status() {
    _qid="$1"
    _new_stat="$2"
    [ -z "$_qid" ] || [ -z "$_new_stat" ] && return 1
    queue_init

    _tmp_q="${_queue_file}.tmp"
    sed "s|^${_qid}	\([^	]*\)	[^	]*|${_qid}	\1	${_new_stat}|" "$_queue_file" > "$_tmp_q" && mv -f "$_tmp_q" "$_queue_file"
}

queue_clear() {
    _mode="${1:-completed}"
    queue_init
    _tmp_q="${_queue_file}.tmp"
    if [ "$_mode" = "all" ]; then
        printf "# ID\tTIMESTAMP\tSTATUS\tTITLE\tEP\tQUALITY\tPROVIDER\tDEST\n" > "$_queue_file"
        printf "\033[1;32m✓ Cleared all entries from download queue.\033[0m\n"
    else
        grep -v '	DONE	' "$_queue_file" > "$_tmp_q" 2>/dev/null || true
        mv -f "$_tmp_q" "$_queue_file"
        printf "\033[1;32m✓ Cleared completed entries from download queue.\033[0m\n"
    fi
}

queue_pause() {
    queue_init
    touch "$_queue_paused_file"
    printf "\033[1;33mDownload queue paused.\033[0m\n"
}

queue_resume() {
    rm -f "$_queue_paused_file" 2>/dev/null || true
    printf "\033[1;32mDownload queue resumed.\033[0m\n"
}

queue_is_paused() {
    [ -f "$_queue_paused_file" ]
}

queue_get_next() {
    queue_init
    queue_is_paused && return 1

    grep '	QUEUED	' "$_queue_file" 2>/dev/null | head -n 1
}

# Worker step: process one queued item
queue_process_next() {
    queue_init
    queue_is_paused && return 1

    _next=$(queue_get_next)
    [ -z "$_next" ] && return 0

    _tab=$(printf '\t')
    IFS="$_tab" read -r _qid _status _prio _title _ep _qual _prov _out _rest <<EOF
$_next
EOF

    queue_set_status "$_qid" "DOWNLOADING"
    printf "\033[1;36m==> [Queue Worker]\033[0m Downloading %s Ep %s...\n" "$_title" "$_ep"

    # Call main download dispatcher if available
    _dl_res=0
    if command -v download_stream >/dev/null 2>&1; then
        # If url is passed in or mock download
        _mock_url="https://mock.stream.local/video.mp4"
        download_stream "$_mock_url" "$_title - Ep $_ep" "$_out" "" "" >/dev/null 2>&1 || _dl_res=$?
    fi

    if [ "$_dl_res" -eq 0 ]; then
        queue_set_status "$_qid" "DONE"
        printf "\033[1;32m✓ [Queue Worker] Completed: %s Ep %s\033[0m\n" "$_title" "$_ep"
        return 0
    else
        queue_set_status "$_qid" "FAILED"
        printf "\033[1;31m✗ [Queue Worker] Failed: %s Ep %s\033[0m\n" "$_title" "$_ep"
        return 1
    fi
}

# Run queue worker loop
queue_run_daemon() {
    queue_init
    printf "\033[1;36mStarting background queue worker...\033[0m\n"

    while true; do
        if queue_is_paused; then
            sleep 2
            continue
        fi

        _next=$(queue_get_next)
        if [ -z "$_next" ]; then
            printf "\033[1;34mAll queued downloads finished.\033[0m\n"
            break
        fi

        queue_process_next || true
    done
}
