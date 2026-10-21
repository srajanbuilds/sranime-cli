#!/usr/bin/env python3
"""
sranime-cli LAN Watch Party & Stream Relay Server
Zero-dependency HTTP streaming server with built-in ANSI/Unicode QR code generator.
"""

import sys
import os
import argparse
import socket
import json
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# --- Pure Python QR Code Generator ---
class QR:
    GF_EXP = [0] * 512
    GF_LOG = [0] * 256
    _initialized = False

    @classmethod
    def init_gf(cls):
        if cls._initialized: return
        x = 1
        for i in range(255):
            cls.GF_EXP[i] = x
            cls.GF_EXP[i + 255] = x
            cls.GF_LOG[x] = i
            x = (x << 1) ^ (0x11d if (x & 0x80) else 0)
        cls._initialized = True

    @classmethod
    def gf_mul(cls, x, y):
        if x == 0 or y == 0: return 0
        return cls.GF_EXP[cls.GF_LOG[x] + cls.GF_LOG[y]]

    @classmethod
    def poly_mul(cls, p1, p2):
        r = [0] * (len(p1) + len(p2) - 1)
        for i, c1 in enumerate(p1):
            for j, c2 in enumerate(p2):
                r[i + j] ^= cls.gf_mul(c1, c2)
        return r

    @classmethod
    def poly_div(cls, dividend, divisor):
        res = list(dividend)
        for i in range(len(dividend) - len(divisor) + 1):
            coef = res[i]
            if coef != 0:
                for j in range(1, len(divisor)):
                    res[i + j] ^= cls.gf_mul(divisor[j], coef)
        return res[len(dividend) - len(divisor) + 1:]

    @classmethod
    def rs_gen_poly(cls, n):
        g = [1]
        for i in range(n):
            g = cls.poly_mul(g, [1, cls.GF_EXP[i]])
        return g

    VERSIONS = {
        1: {'size': 21, 'data': 19, 'ec': 7, 'align': []},
        2: {'size': 25, 'data': 34, 'ec': 10, 'align': [6, 18]},
        3: {'size': 29, 'data': 55, 'ec': 15, 'align': [6, 22]},
    }

    @classmethod
    def encode_data(cls, text, ver):
        spec = cls.VERSIONS[ver]
        raw = text.encode('iso-8859-1', errors='replace')
        bits = '0100' + format(len(raw), '08b')
        for b in raw:
            bits += format(b, '08b')
        max_bits = spec['data'] * 8
        bits = bits[:max_bits]
        bits += '0' * min(4, max_bits - len(bits))
        if len(bits) % 8 != 0:
            bits += '0' * (8 - (len(bits) % 8))
        bytes_data = [int(bits[i:i+8], 2) for i in range(0, len(bits), 8)]
        pad = [0xEC, 0x11]
        p_idx = 0
        while len(bytes_data) < spec['data']:
            bytes_data.append(pad[p_idx])
            p_idx = (p_idx + 1) % 2
        gen = cls.rs_gen_poly(spec['ec'])
        dividend = bytes_data + [0] * spec['ec']
        ec = cls.poly_div(dividend, gen)
        return bytes_data + ec

    @classmethod
    def build_matrix(cls, text):
        cls.init_gf()
        data_len = len(text.encode('iso-8859-1', errors='replace'))
        ver = 1
        if data_len > 17: ver = 2
        if data_len > 32: ver = 3
        spec = cls.VERSIONS[ver]
        size = spec['size']
        matrix = [[None] * size for _ in range(size)]
        reserved = [[False] * size for _ in range(size)]

        def set_func(r, c, val):
            if 0 <= r < size and 0 <= c < size:
                matrix[r][c] = val
                reserved[r][c] = True

        corners = [(0, 0), (0, size - 7), (size - 7, 0)]
        for r_off, c_off in corners:
            for r in range(7):
                for c in range(7):
                    val = 1 if (r in (0, 6) or c in (0, 6) or (2 <= r <= 4 and 2 <= c <= 4)) else 0
                    set_func(r_off + r, c_off + c, val)
            for r in range(-1, 8):
                for c in range(-1, 8):
                    if r in (-1, 7) or c in (-1, 7):
                        set_func(r_off + r, c_off + c, 0)

        for i in range(8, size - 8):
            set_func(6, i, 1 if i % 2 == 0 else 0)
            set_func(i, 6, 1 if i % 2 == 0 else 0)

        if spec['align']:
            for r in spec['align']:
                for c in spec['align']:
                    if reserved[r][c]: continue
                    for dr in range(-2, 3):
                        for dc in range(-2, 3):
                            val = 1 if (abs(dr) == 2 or abs(dc) == 2 or (dr == 0 and dc == 0)) else 0
                            set_func(r + dr, c + dc, val)

        set_func(4 * ver + 9, 8, 1)

        for i in range(9):
            if not reserved[8][i]: reserved[8][i] = True
            if not reserved[i][8]: reserved[i][8] = True
        for i in range(8):
            if not reserved[8][size - 1 - i]: reserved[8][size - 1 - i] = True
            if not reserved[size - 1 - i][8]: reserved[size - 1 - i][8] = True

        raw_codewords = cls.encode_data(text, ver)
        data_bits = ''.join(format(b, '08b') for b in raw_codewords)

        bit_idx = 0
        direction = -1
        c = size - 1
        while c > 0:
            if c == 6: c -= 1
            cols = [c, c - 1]
            rows = range(size - 1, -1, -1) if direction == -1 else range(size)
            for r in rows:
                for col in cols:
                    if not reserved[r][col]:
                        val = int(data_bits[bit_idx]) if bit_idx < len(data_bits) else 0
                        bit_idx += 1
                        if (r + col) % 2 == 0:
                            val ^= 1
                        matrix[r][col] = val
            direction = -direction
            c -= 2

        fmt_bits = '111011111000100'
        set_func(8, 0, int(fmt_bits[0]))
        set_func(8, 1, int(fmt_bits[1]))
        set_func(8, 2, int(fmt_bits[2]))
        set_func(8, 3, int(fmt_bits[3]))
        set_func(8, 4, int(fmt_bits[4]))
        set_func(8, 5, int(fmt_bits[5]))
        set_func(8, 7, int(fmt_bits[6]))
        set_func(8, 8, int(fmt_bits[7]))
        set_func(7, 8, int(fmt_bits[8]))
        set_func(5, 8, int(fmt_bits[9]))
        set_func(4, 8, int(fmt_bits[10]))
        set_func(3, 8, int(fmt_bits[11]))
        set_func(2, 8, int(fmt_bits[12]))
        set_func(1, 8, int(fmt_bits[13]))
        set_func(0, 8, int(fmt_bits[14]))

        for i in range(7):
            set_func(size - 1 - i, 8, int(fmt_bits[i]))
        for i in range(8):
            set_func(8, size - 8 + i, int(fmt_bits[7 + i]))

        return matrix

    @classmethod
    def render_terminal(cls, text):
        m = cls.build_matrix(text)
        size = len(m)
        quiet = 2
        padded = []
        for _ in range(quiet):
            padded.append([0] * (size + 2 * quiet))
        for row in m:
            padded.append([0] * quiet + [1 if x == 1 else 0 for x in row] + [0] * quiet)
        for _ in range(quiet):
            padded.append([0] * (size + 2 * quiet))

        lines = []
        p_len = len(padded)
        for r in range(0, p_len, 2):
            line = "  "
            for c in range(len(padded[0])):
                top = padded[r][c]
                bot = padded[r + 1][c] if r + 1 < p_len else 0
                if top and bot: line += "█"
                elif top and not bot: line += "▀"
                elif not top and bot: line += "▄"
                else: line += " "
            lines.append(line)
        return "\n".join(lines)


# --- LAN IP Detection ---
def get_lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip


# --- HTML5 Dark Mode Player Page ---
def render_html_player(title, ep_no, stream_url, sub_url=None):
    sub_tag = '<track src="/subtitles.vtt" kind="subtitles" srclang="en" label="English" default>' if sub_url else ''
    template = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>__TITLE__ - Episode __EP__ | sranime Watch Party</title>
  <style>
    :root {
      --bg: #090d16;
      --card: rgba(22, 27, 46, 0.7);
      --accent: #6366f1;
      --accent-glow: rgba(99, 102, 241, 0.4);
      --text: #f8fafc;
      --muted: #94a3b8;
      --border: rgba(255, 255, 255, 0.1);
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    body {
      background: var(--bg);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 16px;
    }
    .container {
      width: 100%;
      max-width: 1000px;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    .header {
      background: var(--card);
      backdrop-filter: blur(16px);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 14px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
    }
    .header-left {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .badge {
      background: linear-gradient(135deg, #4f46e5, #7c3aed);
      color: #fff;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.05em;
      text-transform: uppercase;
      padding: 4px 10px;
      border-radius: 20px;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      box-shadow: 0 0 12px var(--accent-glow);
    }
    .dot {
      width: 7px;
      height: 7px;
      background: #22c55e;
      border-radius: 50%;
      animation: pulse 1.5s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.4; transform: scale(0.8); }
    }
    .title {
      font-size: 18px;
      font-weight: 600;
      color: var(--text);
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      max-width: 450px;
    }
    .ep-tag {
      color: #38bdf8;
      font-weight: 700;
    }
    .player-wrap {
      position: relative;
      width: 100%;
      aspect-ratio: 16 / 9;
      background: #000;
      border-radius: 16px;
      overflow: hidden;
      border: 1px solid var(--border);
      box-shadow: 0 20px 50px rgba(0,0,0,0.6);
    }
    video {
      width: 100%;
      height: 100%;
      object-fit: contain;
    }
    .footer {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 12px;
      color: var(--muted);
      padding: 4px 8px;
    }
  </style>
  <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="header-left">
        <div class="badge"><div class="dot"></div> LAN Watch Party</div>
        <div class="title">__TITLE__ &bull; <span class="ep-tag">Ep __EP__</span></div>
      </div>
      <div style="font-size: 13px; color: var(--muted);">sranime-cli</div>
    </div>
    <div class="player-wrap">
      <video id="player" controls autoplay playsinline preload="auto">
        <source src="/stream" type="application/x-mpegURL">
        __SUB_TAG__
      </video>
    </div>
    <div class="footer">
      <div>Synced via local Wi-Fi &bull; Zero Lag</div>
      <div>Keyboard: Space (Play/Pause), &larr;/&rarr; (Seek), F (Fullscreen)</div>
    </div>
  </div>
  <script>
    const video = document.getElementById('player');
    const streamSrc = '/stream';
    if (Hls.isSupported()) {
      const hls = new Hls({ enableWorker: true, lowLatencyMode: true });
      hls.loadSource(streamSrc);
      hls.attachMedia(video);
      hls.on(Hls.Events.MANIFEST_PARSED, function() {
        video.play().catch(() => {});
      });
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
      video.src = streamSrc;
      video.addEventListener('loadedmetadata', function() {
        video.play().catch(() => {});
      });
    }
  </script>
</body>
</html>"""
    return template.replace('__TITLE__', str(title)).replace('__EP__', str(ep_no)).replace('__SUB_TAG__', sub_tag)


# --- HTTP Server Handler ---
class PartyHandler(BaseHTTPRequestHandler):
    video_url = ""
    anime_title = ""
    ep_no = ""
    sub_url = None
    referer = ""

    def log_message(self, format, *args):
        # Silence default server access logging
        pass

    def do_GET(self):
        if self.path == '/' or self.path == '/index.html':
            html = render_html_player(self.anime_title, self.ep_no, self.video_url, self.sub_url)
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(html.encode('utf-8'))
        elif self.path.startswith('/sync'):
            status = {
                'title': self.anime_title,
                'episode': self.ep_no,
                'status': 'playing'
            }
            body = json.dumps(status)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(body.encode('utf-8'))
        elif self.path.startswith('/stream') or self.path.startswith('/video'):
            self.send_response(302)
            self.send_header('Location', self.video_url)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
        elif self.path.startswith('/subtitles.vtt') and self.sub_url:
            self.send_response(302)
            self.send_header('Location', self.sub_url)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()


def run_server(url, title, ep, port=8888, sub=None, ref=None):
    PartyHandler.video_url = url
    PartyHandler.anime_title = title
    PartyHandler.ep_no = ep
    PartyHandler.sub_url = sub
    PartyHandler.referer = ref or ""

    server = HTTPServer(('0.0.0.0', int(port)), PartyHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


def main():
    parser = argparse.ArgumentParser(description="sranime-cli Watch Party LAN Server")
    parser.add_argument('--qr', help="Render terminal QR code for given URL")
    parser.add_argument('--ip', action='store_true', help="Print local LAN IPv4 address")
    parser.add_argument('--serve', action='store_true', help="Start background streaming server")
    parser.add_argument('--url', help="Video stream URL")
    parser.add_argument('--title', default="Anime", help="Anime title")
    parser.add_argument('--ep', default="1", help="Episode number")
    parser.add_argument('--port', type=int, default=8888, help="Server port")
    parser.add_argument('--sub', help="Subtitles URL")
    parser.add_argument('--ref', help="Referer header")

    args = parser.parse_args()

    if args.ip:
        print(get_lan_ip())
        return

    if args.qr:
        print(QR.render_terminal(args.qr))
        return

    if args.serve:
        if not args.url:
            print("Error: --url is required for --serve", file=sys.stderr)
            sys.exit(1)
        run_server(args.url, args.title, args.ep, args.port, args.sub, args.ref)
        return

if __name__ == '__main__':
    main()
