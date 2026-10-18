#!/bin/sh
# lib/sranime-cli/webserver.sh - Local LAN Web Companion Microserver
# Embedded micro HTTP server for phone/tablet control and remote playback

webserver_pid_file="${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli/webserver.pid"

webserver_is_running() {
    if [ -f "$webserver_pid_file" ]; then
        _pid=$(cat "$webserver_pid_file" 2>/dev/null)
        if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

webserver_status() {
    if webserver_is_running; then
        _pid=$(cat "$webserver_pid_file" 2>/dev/null)
        printf "\033[1;32m● sranime-cli Web Companion is running (PID %s)\033[0m\n" "$_pid"
        return 0
    else
        printf "\033[1;33m○ sranime-cli Web Companion is stopped\033[0m\n"
        return 1
    fi
}

webserver_stop() {
    if [ -f "$webserver_pid_file" ]; then
        _pid=$(cat "$webserver_pid_file" 2>/dev/null)
        if [ -n "$_pid" ]; then
            kill "$_pid" 2>/dev/null || true
            rm -f "$webserver_pid_file" 2>/dev/null || true
            printf "\033[1;32m==> Stopped sranime-cli Web Companion (PID %s)\033[0m\n" "$_pid"
            return 0
        fi
    fi
    printf "Web companion is not running.\n"
    return 0
}

webserver_start() {
    _port="${1:-7777}"
    if webserver_is_running; then
        _pid=$(cat "$webserver_pid_file" 2>/dev/null)
        printf "Web companion already running (PID %s) at http://localhost:%s\n" "$_pid" "$_port"
        return 0
    fi

    if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
        printf "\033[1;31m[!] Python 3 is required to launch the web companion.\033[0m\n" >&2
        return 1
    fi

    _py_cmd="python3"
    command -v python3 >/dev/null 2>&1 || _py_cmd="python"

    _state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/sranime-cli"
    mkdir -p "$_state_dir" 2>/dev/null || true

    printf "\033[1;36m==> Launching sranime-cli Web Companion on http://localhost:%s (LAN access enabled)\033[0m\n" "$_port"

    _server_script='
import http.server
import json
import os
import subprocess
import urllib.parse
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 7777
STATE_DIR = sys.argv[2] if len(sys.argv) > 2 else "."
WATCH_LOG = os.path.join(STATE_DIR, "watch.log")

HTML_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>sranime-cli Companion</title>
<style>
  :root { --bg: #0f172a; --card: #1e293b; --text: #f8fafc; --accent: #38bdf8; --border: #334155; }
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: var(--text); margin: 0; padding: 20px; }
  .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border); padding-bottom: 15px; margin-bottom: 20px; }
  h1 { margin: 0; color: var(--accent); font-size: 1.5rem; display: flex; align-items: center; gap: 8px; }
  .badge { background: #059669; color: white; padding: 4px 8px; border-radius: 4px; font-size: 0.8rem; }
  .search-box { display: flex; gap: 10px; margin-bottom: 25px; }
  input { flex: 1; padding: 12px; border-radius: 8px; border: 1px solid var(--border); background: var(--card); color: var(--text); font-size: 1rem; }
  button { background: var(--accent); color: #0f172a; border: none; padding: 12px 20px; border-radius: 8px; font-weight: bold; cursor: pointer; }
  .section-title { font-size: 1.1rem; margin-bottom: 12px; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.05em; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 15px; }
  .card { background: var(--card); border: 1px solid var(--border); border-radius: 8px; padding: 15px; display: flex; flex-direction: column; justify-content: space-between; }
  .card h3 { margin: 0 0 6px 0; font-size: 1.1rem; }
  .meta { color: #94a3b8; font-size: 0.85rem; margin-bottom: 12px; }
  .actions { display: flex; gap: 8px; }
  .btn-play { background: #3b82f6; color: white; border: none; padding: 8px 12px; border-radius: 6px; cursor: pointer; flex: 1; font-weight: 500; }
  .btn-cast { background: #8b5cf6; color: white; border: none; padding: 8px 12px; border-radius: 6px; cursor: pointer; flex: 1; font-weight: 500; }
</style>
</head>
<body>
<div class="header">
  <h1>⚡ sranime-cli <span>Companion</span></h1>
  <span class="badge">LAN Connected</span>
</div>
<div class="search-box">
  <input type="text" id="searchInput" placeholder="Search anime to stream or cast...">
  <button onclick="searchAnime()">Search</button>
</div>
<div class="section-title">Recent Watch History</div>
<div class="grid" id="historyList">Loading history...</div>
<script>
async function loadHistory() {
  try {
    const res = await fetch("/api/history");
    const data = await res.json();
    const container = document.getElementById("historyList");
    if (!data || !data.length) {
      container.innerHTML = "<p style=\\"color:#94a3b8\\">No viewing history recorded yet.</p>";
      return;
    }
    container.innerHTML = data.map(item => `
      <div class="card">
        <div>
          <h3>${item.title}</h3>
          <div class="meta">Episode ${item.episode} • ${item.action} • ${item.time}</div>
        </div>
        <div class="actions">
          <button class="btn-play" onclick="playAnime(\x27${item.title}\x27, \x27${item.episode}\x27)">▶ Play Desktop</button>
          <button class="btn-cast" onclick="castAnime(\x27${item.title}\x27, \x27${item.episode}\x27)">📺 Cast TV</button>
        </div>
      </div>
    `).join("");
  } catch (e) {
    document.getElementById("historyList").innerHTML = "<p style=\\"color:#ef4444\\">Failed to load history.</p>";
  }
}
function playAnime(title, ep) {
  fetch("/api/play?title=" + encodeURIComponent(title) + "&ep=" + ep);
  alert("Playback requested for " + title + " Episode " + ep);
}
function castAnime(title, ep) {
  fetch("/api/cast?title=" + encodeURIComponent(title) + "&ep=" + ep);
  alert("Cast requested for " + title + " Episode " + ep);
}
loadHistory();
</script>
</body>
</html>"""

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/" or parsed.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_PAGE.encode("utf-8"))
        elif parsed.path == "/api/history":
            items = []
            if os.path.isfile(WATCH_LOG):
                with open(WATCH_LOG, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        parts = line.strip().split("\t")
                        if len(parts) >= 5:
                            items.append({
                                "time": parts[0],
                                "action": parts[1],
                                "episode": parts[2],
                                "title": parts[4]
                            })
            items.reverse()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(items[:20]).encode("utf-8"))
        elif parsed.path == "/api/play":
            query = urllib.parse.parse_qs(parsed.query)
            title = query.get("title", [""])[0]
            ep = query.get("ep", ["1"])[0]
            if title:
                subprocess.Popen(["sranime-cli", "-e", ep, title])
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b"{\"status\":\"ok\"}")
        elif parsed.path == "/api/cast":
            query = urllib.parse.parse_qs(parsed.query)
            title = query.get("title", [""])[0]
            ep = query.get("ep", ["1"])[0]
            if title:
                subprocess.Popen(["sranime-cli", "--cast", "", "-e", ep, title])
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b"{\"status\":\"ok\"}")
        else:
            self.send_response(404)
            self.end_headers()

server = http.server.HTTPServer(("0.0.0.0", PORT), Handler)
server.serve_forever()
'

    $_py_cmd -c "$_server_script" "$_port" "$_state_dir" >/dev/null 2>&1 &
    _new_pid=$!
    printf "%s\n" "$_new_pid" > "$webserver_pid_file"
    printf "\033[1;32m✓ sranime-cli Web Companion started in background (PID %s)\033[0m\n" "$_new_pid"
    return 0
}
