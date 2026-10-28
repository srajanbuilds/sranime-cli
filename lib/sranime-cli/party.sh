#!/bin/sh
# sranime-cli LAN Stream Relay & Terminal QR Code Watch Party Engine
#
# Provides local Wi-Fi video streaming relay to phones, tablets, smart TVs,
# and roommates with zero-dependency ANSI/Unicode QR code terminal rendering.
#
# Provides:
#   - party_detect_lan_ip
#   - party_render_qr <url>
#   - party_start_server <video_url> <anime_title> <ep_no> [port] [sub_url] [referer]
#   - party_stop
#   - party_status
#   - party_is_running

_party_state_dir="${SRANIME_CLI_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli}"
_party_pid_file="$_party_state_dir/party.pid"
_party_meta_file="$_party_state_dir/party.tsv"

_ensure_party_state_dir() {
    [ ! -d "$_party_state_dir" ] && mkdir -p "$_party_state_dir" 2>/dev/null || true
}

_get_python_cmd() {
    if python -c "import sys" >/dev/null 2>&1; then
        printf "python"
    elif python3 -c "import sys" >/dev/null 2>&1; then
        printf "python3"
    fi
}

_get_server_py() {
    if [ -n "$SRANIME_LIB_DIR" ] && [ -f "$SRANIME_LIB_DIR/party_server.py" ]; then
        printf "%s/party_server.py" "$SRANIME_LIB_DIR"
        return 0
    fi
    if [ -f "lib/sranime-cli/party_server.py" ]; then
        printf "%s/lib/sranime-cli/party_server.py" "$(pwd)"
        return 0
    fi
    _d=$(cd "$(dirname "$0")" && pwd)
    if [ -f "$_d/party_server.py" ]; then
        printf "%s/party_server.py" "$_d"
        return 0
    fi
    if [ -f "$_d/../lib/sranime-cli/party_server.py" ]; then
        printf "%s/../lib/sranime-cli/party_server.py" "$_d"
        return 0
    fi
    printf "lib/sranime-cli/party_server.py"
}

party_detect_lan_ip() {
    _py_cmd=$(_get_python_cmd)
    _py_script=$(_get_server_py)
    if [ -n "$_py_cmd" ] && [ -f "$_py_script" ]; then
        _ip=$("$_py_cmd" "$_py_script" --ip 2>/dev/null)
        if [ -n "$_ip" ]; then
            printf "%s\n" "$_ip"
            return 0
        fi
    fi

    # Fallback platform checks
    case "$(uname -s 2>/dev/null)" in
        Linux*)
            _ip=$(hostname -I 2>/dev/null | awk '{print $1}')
            [ -n "$_ip" ] && printf "%s\n" "$_ip" && return 0
            _ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
            [ -n "$_ip" ] && printf "%s\n" "$_ip" && return 0
            ;;
        Darwin*)
            _ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
            [ -n "$_ip" ] && printf "%s\n" "$_ip" && return 0
            ;;
        *MINGW* | *MSYS* | *CYGWIN*)
            if command -v powershell >/dev/null 2>&1; then
                _ip=$(powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { \$_.IPAddress -notlike '127*' -and \$_.IPAddress -notlike '169.254*' }).IPAddress | Select-Object -First 1" 2>/dev/null | tr -d '\r\n[:space:]')
                [ -n "$_ip" ] && printf "%s\n" "$_ip" && return 0
            fi
            ;;
    esac

    printf "127.0.0.1\n"
}

party_render_qr() {
    _url="$1"
    [ -z "$_url" ] && return 1

    # 1. qrencode if available
    if command -v qrencode >/dev/null 2>&1; then
        qrencode -t ANSI "$_url" 2>/dev/null && return 0
    fi

    # 2. Built-in zero-dependency Python QR generator
    _py_cmd=$(_get_python_cmd)
    _py_script=$(_get_server_py)
    if [ -n "$_py_cmd" ] && [ -f "$_py_script" ]; then
        "$_py_cmd" "$_py_script" --qr "$_url" 2>/dev/null && return 0
    fi

    # 3. Text fallback
    printf "  [QR Unavailable - Open URL in browser: %s]\n" "$_url"
}

party_is_running() {
    if [ -f "$_party_pid_file" ]; then
        _pid=$(cat "$_party_pid_file" 2>/dev/null | tr -d '[:space:]')
        if [ -n "$_pid" ]; then
            if kill -0 "$_pid" 2>/dev/null; then
                return 0
            fi
            if ps -p "$_pid" >/dev/null 2>&1; then
                return 0
            fi
        fi
    fi
    return 1
}

party_start_server() {
    _v_url="$1"
    _title="${2:-Anime}"
    _ep="${3:-1}"
    _port="${4:-8888}"
    _sub="${5:-}"
    _ref="${6:-}"

    _ensure_party_state_dir

    if party_is_running; then
        party_stop 2>/dev/null || true
    fi

    _py_cmd=$(_get_python_cmd)
    _py_script=$(_get_server_py)

    [ -z "$_py_cmd" ] && printf "Error: Python runtime required for Watch Party relay server.\n" >&2 && return 1

    _lan_ip=$(party_detect_lan_ip)
    _stream_http_url="http://${_lan_ip}:${_port}"

    # Launch background HTTP streaming relay
    "$_py_cmd" "$_py_script" --serve --url "$_v_url" --title "$_title" --ep "$_ep" --port "$_port" ${_sub:+--sub "$_sub"} ${_ref:+--ref "$_ref"} >/dev/null 2>&1 &
    _server_pid=$!

    echo "$_server_pid" > "$_party_pid_file"
    printf "%s\t%s\t%s\t%s\t%s\n" "$_server_pid" "$_port" "$_lan_ip" "$_title" "$_ep" > "$_party_meta_file"

    # Display Watch Party Hub Banner & QR Code
    printf "\n\033[1;35m╭────────────────────────────────────────────────────────────────────────╮\033[0m\n"
    printf "\033[1;35m│\033[0m \033[1;32m● [LAN WATCH PARTY]\033[0m \033[1;37mStream Relay Online & Synchronized\033[0m         \033[1;35m│\033[0m\n"
    printf "\033[1;35m├────────────────────────────────────────────────────────────────────────┤\033[0m\n"
    printf "\033[1;35m│\033[0m \033[1;36mAnime:\033[0m      %-58s \033[1;35m│\033[0m\n" "$_title (Ep $_ep)"
    printf "\033[1;35m│\033[0m \033[1;36mStream URL:\033[0m \033[1;33m%-58s\033[0m \033[1;35m│\033[0m\n" "$_stream_http_url"
    printf "\033[1;35m│\033[0m \033[1;36mAction:\033[0m     Scan QR below with phone/tablet or share URL on local Wi-Fi \033[1;35m│\033[0m\n"
    printf "\033[1;35m╰────────────────────────────────────────────────────────────────────────╯\033[0m\n\n"

    party_render_qr "$_stream_http_url"
    printf "\n"
    return 0
}

party_stop() {
    if [ ! -f "$_party_pid_file" ]; then
        printf "No active Watch Party streaming relay is running.\n"
        return 0
    fi

    _pid=$(cat "$_party_pid_file" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$_pid" ]; then
        kill "$_pid" 2>/dev/null || true
        case "$(uname -s 2>/dev/null)" in
            *MINGW* | *MSYS* | *CYGWIN*)
                taskkill //F //PID "$_pid" >/dev/null 2>&1 || true
                ;;
        esac
    fi

    rm -f "$_party_pid_file" "$_party_meta_file" 2>/dev/null || true
    printf "\033[1;32m==> [Watch Party] Streaming relay stopped successfully.\033[0m\n"
    return 0
}

party_status() {
    if ! party_is_running; then
        printf "\033[1;33m[Watch Party] No active streaming relay is currently running.\033[0m\n"
        return 1
    fi

    _pid=$(cat "$_party_pid_file" 2>/dev/null | tr -d '[:space:]')
    _port="8888"
    _ip="127.0.0.1"
    _title="Anime"
    _ep="1"

    if [ -f "$_party_meta_file" ]; then
        _tab=$(printf '\t')
        IFS="$_tab" read -r _m_room _port _ip _title _ep _rest < "$_party_meta_file"
    fi

    _url="http://${_ip}:${_port}"
    printf "\033[1;35m╭────────────────────────────────────────────────────────────────────────╮\033[0m\n"
    printf "\033[1;35m│\033[0m \033[1;32m● [WATCH PARTY STATUS]\033[0m \033[1;37mActive Local Relay\033[0m                       \033[1;35m│\033[0m\n"
    printf "\033[1;35m├────────────────────────────────────────────────────────────────────────┤\033[0m\n"
    printf "\033[1;35m│\033[0m \033[1;36mPID:\033[0m        %-58s \033[1;35m│\033[0m\n" "$_pid"
    printf "\033[1;35m│\033[0m \033[1;36mTitle:\033[0m      %-58s \033[1;35m│\033[0m\n" "$_title (Ep $_ep)"
    printf "\033[1;35m│\033[0m \033[1;36mStream URL:\033[0m \033[1;33m%-58s\033[0m \033[1;35m│\033[0m\n" "$_url"
    printf "\033[1;35m╰────────────────────────────────────────────────────────────────────────╯\033[0m\n"
    return 0
}
