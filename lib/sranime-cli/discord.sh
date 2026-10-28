#!/bin/sh
# sranime-cli discord module — lightweight Discord IPC Rich Presence client
#
# Provides:
#   - discord_find_pipe
#   - discord_format_handshake
#   - discord_format_activity <title> <ep> <mode> <pid> [start_time]
#   - discord_send_payload <socket_path> <opcode> <json>
#   - discord_start_presence <title> <ep> <mode> <player_pid>

DISCORD_CLIENT_ID="${SRANIME_DISCORD_CLIENT_ID:-1198574362143891466}"

# Find active Discord IPC socket or Windows named pipe
discord_find_pipe() {
    case "$(uname -s 2>/dev/null)" in
        *MINGW* | *MSYS* | *CYGWIN*)
            # Windows Named Pipe
            _i=0
            while [ "$_i" -le 9 ]; do
                _pipe='\\.\pipe\discord-ipc-'$_i
                # Check pipe existence via powershell or test if available
                if [ -e "$_pipe" ] 2>/dev/null; then
                    printf "%s" "$_pipe"
                    return 0
                fi
                _i=$((_i + 1))
            done
            ;;
        *)
            # Unix Domain Sockets
            for _base in "$XDG_RUNTIME_DIR" "/tmp" "$TMPDIR"; do
                [ -z "$_base" ] || [ ! -d "$_base" ] && continue
                _i=0
                while [ "$_i" -le 9 ]; do
                    _sock="${_base}/discord-ipc-$_i"
                    if [ -S "$_sock" ]; then
                        printf "%s" "$_sock"
                        return 0
                    fi
                    _i=$((_i + 1))
                done
            done
            ;;
    esac
    return 1
}

# Generate Opcode 0 Handshake JSON
discord_format_handshake() {
    _cid="${1:-$DISCORD_CLIENT_ID}"
    printf '{"v": 1, "client_id": "%s"}' "$_cid"
}

# Generate Opcode 1 Activity Frame JSON
discord_format_activity() {
    _title="$1"
    _ep="$2"
    _mode="${3:-Sub}"
    _pid="${4:-1}"
    _start="${5:-$(date +%s 2>/dev/null || echo 0)}"

    _safe_title=$(printf '%s' "$_title" | sed 's/"/\\"/g')
    _state="Episode ${_ep} (${_mode})"

    cat << ACTIVITYEOF
{
  "cmd": "SET_ACTIVITY",
  "args": {
    "pid": $_pid,
    "activity": {
      "details": "$_safe_title",
      "state": "$_state",
      "timestamps": {
        "start": $_start
      },
      "assets": {
        "large_image": "mpv",
        "large_text": "$_safe_title",
        "small_image": "play",
        "small_text": "Streaming via sranime-cli"
      }
    }
  },
  "nonce": "$_start"
}
ACTIVITYEOF
}

# Send framed payload to Discord IPC socket
# Framing: [Opcode: 4 bytes uint32 LE] [Length: 4 bytes uint32 LE] [JSON Payload]
discord_send_payload() {
    _pipe="$1"
    _opcode="${2:-1}"
    _json="$3"

    [ -z "$_pipe" ] || [ -z "$_json" ] && return 1

    # Use python if available for cross-platform binary packing
    if command -v python >/dev/null 2>&1; then
        python -c '
import sys, socket, struct
pipe_path, opcode, payload = sys.argv[1], int(sys.argv[2]), sys.argv[3].encode("utf-8")
header = struct.pack("<II", opcode, len(payload))
try:
    if pipe_path.startswith("\\"):
        with open(pipe_path, "wb") as f:
            f.write(header + payload)
    else:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(pipe_path)
        s.sendall(header + payload)
        s.close()
except Exception:
    sys.exit(1)
' "$_pipe" "$_opcode" "$_json" 2>/dev/null || return 1
        return 0
    fi

    return 1
}

# Launch background Discord Rich Presence watcher alongside player
discord_start_presence() {
    _title="$1"
    _ep="$2"
    _mode="${3:-Sub}"
    _player_pid="$4"

    _pipe=$(discord_find_pipe 2>/dev/null || true)
    [ -z "$_pipe" ] && return 0

    (
        # 1. Send Handshake
        _hs=$(discord_format_handshake)
        discord_send_payload "$_pipe" 0 "$_hs" 2>/dev/null || true

        # 2. Send Activity
        _act=$(discord_format_activity "$_title" "$_ep" "$_mode" "$_player_pid")
        discord_send_payload "$_pipe" 1 "$_act" 2>/dev/null || true

        # 3. Monitor player PID; clear presence when player exits
        if [ -n "$_player_pid" ] && [ "$_player_pid" -gt 0 ] 2>/dev/null; then
            while kill -0 "$_player_pid" 2>/dev/null; do
                sleep 5
            done
            # Clear Activity
            _clear="{\"cmd\":\"SET_ACTIVITY\",\"args\":{\"pid\":${_player_pid},\"activity\":null},\"nonce\":\"clear\"}"
            discord_send_payload "$_pipe" 1 "$_clear" 2>/dev/null || true
        fi
    ) >/dev/null 2>&1 &
}
