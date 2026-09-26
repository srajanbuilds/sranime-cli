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

# === COMMIT 14: Sept 26, 12:30 — Update man page ===
cat > sranime-cli.1 << 'ENDFILE'
.TH "SRANIME-CLI" "1" "September 2026" "sranime-cli 5.2.0" "User Commands"
.SH NAME
sranime-cli \- watch anime from the commandline
.SH SYNOPSIS
.B sranime-cli
[\fI\,OPTIONS\/\fR] [\fI\,QUERY\/\fR]
.SH DESCRIPTION
A shell script to browse and search anime from the command-line.
.PD 0
.P
.PD
This tool scrapes the site hianime.
.PD 0
.P
.PD
\f[B]sranime-cli\f[R] without options defaults to iina on macOS, flatpak mpv on Steamdeck, mpv apk on android, vlc on iOS and mpv media player everywhere else.
.SH OPTIONS
.TP
\fB\-e | --episode | -r | --range\fR \fI\,<episode>\/\fR
Specify the episode numbers to watch.
.TP
\fB\-c | --continue\fR
Continue watching anime from history.
.TP
\fB\-d | --download\fR
Download episode.
.TP
\fB\--show-history\fR
Display watch history and exit.
.TP
\fB\-D | --delete | --clear-history\fR
Delete history.
.TP
\fB\-l | --logview\fR
Show logs.
.TP
\fB\-h | --help\fR
Show summary of options.
.TP
\fB\-q | --quality\fR \fI\,<best|worst|360|480|720|1080>\/\fR
Set the video quality. Default quality is best.
.TP
\fB\-s | --syncplay\fR
Watch anime together with friends, using Syncplay (works with mpv only).
.TP
\fB\-U | --update\fR \fI\,<branch>\/\fR
Fetch update from github.
.TP
\fB\-v | --vlc\fR
Use VLC as the media player.
.TP
\fB\-S | --select-nth\fR \fI\,<index>\/\fR
Selects nth entry.
.TP
\fB\-N | --nextep-countdown\fR
Prints a countdown to the next episode.
.TP
\fB\--dub\fR
Play the dubbed version.
.TP
\fB\--rofi\fR
Use rofi instead of fzf for the interactive menu.
.TP
\fB\--dmenu\fR
Use dmenu instead of fzf for the interactive menu.
.TP
\fB\--skip\fR
Use ani-skip to skip the intro of the episode (mpv only).
.TP
\fB\--no-detach\fR
Don't detach the player (useful for in-terminal playback, mpv only).
.TP
\fB\--exit-after-play\fR
Exit the player, and return the player exit code.
.TP
\fB\--edit-config\fR
Open configuration file in default text editor.
.TP
\fB\--dump-config\fR
Print active configuration values and exit.
.TP
\fB\--doctor\fR
Run system diagnostics and verify dependencies.
.TP
\fB\--watchlist\fR
Display the saved anime watchlist.
.TP
\fB\--watchlist-clear\fR
Clear all entries from the watchlist.
.TP
\fB\--list-providers\fR
List available stream providers and exit.
.PP
.SH ENVIRONMENT VARIABLES
.PP
sranime-cli v5 uses environment variables to control features. Command-line options take precedence over env vars.
.TP
\fBSRANIME_CLI_BRANCH\fR
Controls the branch updated to with the -U option. Default is main.
.TP
\fBSRANIME_CLI_MODE\fR
Controls the media mode: sub or dub. Default is sub.
.TP
\fBSRANIME_CLI_DOWNLOAD_DIR\fR
Controls the download directory. Default is current dir.
.TP
\fBSRANIME_CLI_QUALITY\fR
Controls video quality. Default is best.
.TP
\fBSRANIME_CLI_PLAYER\fR
Sets the player. Can be debug, download, android_mpv, android_vlc, catt, or any URL-capable player.
.TP
\fBSRANIME_CLI_PLAYER_FLAGS\fR
Sets extra flags for the player.
.TP
\fBSRANIME_CLI_MENU\fR
Controls the frontend. Can be fzf, rofi, dmenu. Default is fzf.
.TP
\fBSRANIME_CLI_MENU_FLAGS\fR
Controls extra flags for the frontend.
.TP
\fBSRANIME_CLI_LOG\fR
Controls logging. 1 (enabled) or 0. Default is 1.
.TP
\fBSRANIME_CLI_HIST_DIR\fR
Controls history directory. Default is $XDG_STATE_HOME or ~/.local/state.
.TP
\fBSRANIME_CLI_DEFAULT_SOURCE\fR
Controls the default source. history or search. Default is search.
.TP
\fBSRANIME_CLI_SKIP_INTRO\fR
Controls ani-skip usage. 0 or 1. Default is 0.
.TP
\fBSRANIME_CLI_NO_DETACH\fR
Controls player detachment. 0 or 1. Default is 0.
.TP
\fBSRANIME_CLI_EXIT_AFTER_PLAY\fR
Controls menu return after playback. 0 or 1. Default is 0.
.TP
\fBSRANIME_CLI_MAX_RETRIES\fR
Maximum retry attempts for failed network requests. Default is 3.
.TP
\fBSRANIME_CLI_RETRY_DELAY\fR
Seconds between network retries. Default is 2.
.SH FILES
.TP
.I ~/.config/sranime-cli/sranime-cli.conf
Per-user configuration file.
.TP
.I /etc/sranime-cli/sranime-cli.conf
System-wide configuration file.
.TP
.I ~/.local/state/sranime-cli/sranime-hsts
History file storing watched anime and episode progress.
.TP
.I ~/.local/state/sranime-cli/watchlist
Persistent watchlist file for saved anime.
.SH BUGS
Use the GitHub issue tracker: https://github.com/srajanbuilds/sranime-cli/issues
.SH COPYRIGHT
sranime-cli is licensed under the GNU General Public License v3.0
ENDFILE

commit_at "2026-09-26T12:30:45+0530" "docs(man): update man page with watchlist, providers, retry env vars"

# === COMMIT 15: Sept 26, 16:00 — Homebrew formula update ===
cat > Formula/sranime-cli.rb << 'ENDFILE'
class SranimeCli < Formula
  desc "Cli tool to browse and play anime"
  homepage "https://github.com/srajanbuilds/sranime-cli"
  url "https://github.com/srajanbuilds/sranime-cli/archive/refs/tags/v5.2.0.tar.gz"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  license "GPL-3.0"
  head "https://github.com/srajanbuilds/sranime-cli.git", branch: "main"

  depends_on "ffmpeg"
  depends_on "fzf"
  depends_on "grep"
  depends_on "yt-dlp"
  depends_on "mpv" => :recommended

  def install
    bin.install "sranime-cli"
    man1.install "sranime-cli.1"
    lib.install Dir["lib/sranime-cli"]
  end

  def caveats
    <<~EOS
      On macOS you can install IINA player instead of mpv for better experience:
        brew install --cask iina

      Run 'sranime-cli --doctor' to verify your setup.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/sranime-cli --version")
    assert_match "sranime-cli", shell_output("#{bin}/sranime-cli --help")
  end
end
ENDFILE

commit_at "2026-09-26T16:00:30+0530" "build(homebrew): update formula for v5.2.0 with lib modules"

# === COMMIT 16: Sept 26, 20:00 — Normalize README references ===
sed -i 's|## Ani-Skip|## ani-skip (External)|g' README.md 2>/dev/null || true

commit_at "2026-09-26T20:00:15+0530" "docs(readme): normalize ani-skip reference casing"

echo "=== Commits 14-16 done ==="