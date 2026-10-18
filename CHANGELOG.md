# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [6.0.0] - 2026-09-28

### Added
- **Multi-Language Subtitle & Audio Subsystem (`lib/sranime-cli/subtitles.sh`)**:
  - `--sub-lang, -sl <lang>`: Select preferred subtitle language (e.g. `es`, `fr`, `de`, `it`, `pt`, `ar`, `en`).
  - `--audio-lang, -al <lang>`: Select preferred audio stream language (e.g. `ja`, `en`, `es`).
  - Dynamic subtitle track extractor for provider JSON and HLS master manifests with language code normalizer.
  - Generates player-specific subtitle and audio track flags (`--slang`, `--alang`, `--sub-file`).
  - Dedicated unit test suite (`test/test_subtitles.sh`) with 19 automated tests.
- **Smart TV & Chromecast Casting Subsystem (`lib/sranime-cli/cast.sh`)**:
  - `--cast [device]`: Beam streaming video directly to a Smart TV, Chromecast, or Google Cast receiver via `catt`.
  - `--cast-devices`: Scan local network for discoverable Cast targets.
  - Forwarding of video URLs, HTTP headers, and subtitle tracks to external displays.
  - Dedicated unit test suite (`test/test_cast.sh`) with 6 automated tests.
- **Embedded Local LAN Web Companion (`lib/sranime-cli/webserver.sh`)**:
  - `--web [port]`: Starts a lightweight, mobile-responsive local web microserver (default port: `7777`).
  - Access watch history, search anime, and trigger desktop playback or TV casting from any phone or tablet on the local WiFi network.
  - `--web-stop` and `--web-status`: Manage the background web companion process.
  - Dedicated unit test suite (`test/test_webserver.sh`) with 6 automated tests.
- **Master Test Suite Expansion**:
  - Expanded test suites to 14 automated suites and 261 total unit tests, all passing with zero regressions.

## [5.8.0] - 2026-09-28

### Added
- **Media Server Bridge & Metadata Engine (`lib/sranime-cli/nfo.sh`)**:
  - `--nfo` flag: Automatically generates standard Jellyfin, Plex, and Kodi XML metadata files during downloads.
  - Generates `tvshow.nfo` in the anime series directory with title, original Japanese title, synopsis, studio, broadcast year, genres, rating, and AniList/MyAnimeList unique IDs.
  - Generates episode `.nfo` files (`${anime} - S01E${ep} [${quality}].nfo`) alongside video files.
  - Automated artwork fetcher downloading `poster.jpg` and `fanart.jpg` into the series directory.
  - Multi-language subtitle sidecar extraction (`--save-subs`): Downloads external `.vtt`/`.srt` subtitle streams named identically to the video file according to Plex/Jellyfin naming conventions.
  - Dedicated unit test suite (`test/test_nfo.sh`) with 19 automated tests.
- **Asynchronous Background Download Queue Daemon (`lib/sranime-cli/queue.sh`)**:
  - `--queue` flag: Enqueues episode downloads asynchronously into a persistent TSV queue (`$XDG_STATE_HOME/sranime-cli/queue.tsv`) without locking the interactive terminal.
  - `--queue-status`: Displays a clean ANSI dashboard table of queued, active, and completed downloads with status badges.
  - `--queue-start`: Launches the background worker daemon to process queued downloads sequentially.
  - `--queue-pause` & `--queue-resume`: Control background worker execution.
  - `--queue-clear [completed|all]`: Purges finished or all queue entries.
  - Dedicated unit test suite (`test/test_queue.sh`) with 20 automated tests.
  - Master test suite expanded to 11 suites and 220 automated tests passing with zero failures.

## [5.7.0] - 2026-09-28

### Added
- **MyAnimeList (MAL) Cloud Integration (`lib/sranime-cli/scrobbler.sh`)**:
  - Interactive OAuth2 PKCE authentication flow via `sranime-cli --login mal`.
  - Secure credential storage supporting both AniList and MyAnimeList accounts simultaneously.
  - Dual-tracker synchronization: MPV playback scrobbling automatically updates episode completions to both AniList and MyAnimeList concurrently.
  - Tracker account status reporting (`sranime-cli --scrobble-status`) displaying connection status and usernames for all authenticated services.
- **Two-Way Library Portability & XML Synchronization**:
  - `sranime-cli --export-mal [path]`: Exports lifetime watch history into standardized MyAnimeList XML format for instant backup or migration.
  - `sranime-cli --import-mal <path>`: Imports existing anime watch histories from MyAnimeList XML export files directly into the local lifetime watch log.
  - Unit test suite expanded to 32 tests in `test/test_scrobbler.sh` covering verification, credential storage, XML export formatting, and XML parsing.
  - CLI flag test suite expanded to 41 tests in `test/test_cli_flags.sh`.
  - Comprehensive shell completion support across Bash, Zsh, and Fish, plus man page (`sranime-cli.1`).

## [5.6.0] - 2026-09-28

### Added
- **Intelligent Discovery Engine (`lib/sranime-cli/discovery.sh`)**:
  - `--seasonal [season] [year]` flag to browse popular anime from the current or specified broadcast season.
  - `--trending` flag to discover top trending anime releases.
  - `--calendar / --schedule [hours]` command rendering upcoming broadcast tables with live countdown timers (`In 2h 15m`).
  - `--similar [title]` recommendation engine querying AniList's recommendation graphs with community vote rankings.
  - Interactive selection from discovery lists launches episode selection and streaming automatically.
  - Dedicated unit test suite (`test/test_discovery.sh`) with 10 automated tests.

## [5.5.0] - 2026-09-28

### Added
- **Continuous Autoplay Binging Engine (`lib/sranime-cli/playback.sh`)**:
  - `-A, --autoplay` flag to automatically queue and stream subsequent episodes without returning to the menu or re-running commands.
  - `--autoplay-limit [count]` flag to restrict binge sessions to a specific number of episodes.
  - Countdown intermission banner with graceful cancellation (`Ctrl+C`).
- **Timestamp-Precision Resumption & Checkpoints**:
  - Automatic playback position tracking via MPV Lua observer (`shutdown` event and periodic 10-second timer).
  - `-R, --resume` flag to seek immediately to the exact second where you left off.
  - `--start-time [time]` flag supporting `MM:SS`, `HH:MM:SS`, or integer seconds.
  - `--show-checkpoints` command displaying a table of in-progress anime titles, episode numbers, timestamps, and completion percentages.
  - `--clear-checkpoints` command to reset stored playback positions.
  - Unit test suite (`test/test_playback.sh`) with 19 automated tests.

## [5.4.0] - 2026-09-28

### Added
- **Cloud Tracker Synchronization (AniList & Scrobbler)**:
  - Interactive OAuth2 PIN authentication via `sranime-cli --login anilist`.
  - Secure credential storage in `$XDG_CONFIG_HOME/sranime-cli/auth.json` with strict `0600` permissions.
  - Automatic title-to-MediaID resolution (`scrobble_resolve_media_id`) with local TSV caching (`scrobble_id_map.tsv`).
  - Universal MPV Lua progress hook (`scrobble_prepare_script`) detecting 80% playback completion and EOF events.
  - Automatic GraphQL mutation dispatch (`SaveMediaListEntry`) to update progress on AniList.
  - Interactive cloud watchlist sync (`sranime-cli --sync`) populating `fzf` directly with Currently Watching shows and calculating the next episode.
  - Non-interactive watchlist inspection via `sranime-cli --sync-list`.
  - `sranime-cli --scrobble-status` and `sranime-cli --logout [service]`.
  - `--no-scrobble` / `--scrobble` session flags and `auto_scrobble` configuration variable.
  - Unit test suite for scrobbler (`test/test_scrobbler.sh`) with 22 automated tests.

- **Accelerated Parallel Downloads & Batch Engine**:
  - Downloader hierarchy prioritizing `aria2c` 16-connection chunking, with seamless fallback to `yt-dlp` (HLS extraction), `ffmpeg`, and `curl`.
  - Robust cross-platform filename sanitization removing illegal filesystem characters (`\ / : * ? " < > |`).
  - Atomic `.part` buffering to prevent corrupted incomplete downloads.
  - Pure POSIX episode range expression parser (`parse_episode_range`) supporting `-e 1-12`, `-e 1,3,5-8`, and `-e all`.
  - Plex and Jellyfin standardized season folder structure formatting: `${download_dir}/${anime}/Season 01/${anime} - S01E${ep:02d} [${quality}].mp4`.
  - Batch queue integration directly into playback dispatcher with episode summary reports.
  - Unit test suite for downloads (`test/test_download.sh`) with 17 automated tests.

- **Social & Multiplayer Integrations**:
  - Native Discord IPC Rich Presence client (`lib/sranime-cli/discord.sh`) connecting to UNIX domain sockets and Windows named pipes without external daemons.
  - Opcode 0 Handshake and Opcode 1 `SET_ACTIVITY` payload framing with playback timestamps and MPV asset art.
  - Background presence monitor tracking player PID and clearing status upon player exit.
  - Turnkey Syncplay watch party integration (`lib/sranime-cli/syncplay.sh`).
  - `--room [name]` CLI option to set room name and automatically launch platform Syncplay executable.
  - `--discord` and `--no-discord` flags to toggle Rich Presence.
  - Unit test suite (`test/test_discord.sh`) with 10 automated tests.

- **Packaging, Multi-OS CI/CD & Distribution**:
  - Windows Scoop manifest (`bucket/sranime-cli.json` and `sranime-cli.json`) with auto-update checks and binary shims (`sranime-cli.cmd`, `sranime`).
  - Arch Linux AUR package definition (`PKGBUILD`).
  - Homebrew formula (`Formula/sranime-cli.rb`) updated for `lib/` modules, man page, and completions.
  - Synchronized Bash, Zsh, and Fish shell autocompletions for all CLI flags.
  - Updated `Makefile` with clean install and uninstall targets for `lib/sranime-cli/`.
  - Updated universal `install.sh` and `uninstall.sh` with library module installation.
  - GitHub Actions multi-OS continuous integration matrix testing across Ubuntu, macOS, and Windows Git Bash.

## [5.3.0] - 2026-09-28

### Added
- Multi-provider fallback engine (`lib/sranime-cli/providers.sh`) with zero-downtime automatic failover.
- AllAnime provider plugin (`lib/sranime-cli/providers/allanime.sh`) with GraphQL search API.
- GogoAnime / Anitaku provider plugin (`lib/sranime-cli/providers/gogo.sh`) with HTML scraper fallback.
- `-p, --provider` CLI option to manually select or force stream provider.
- Enhanced self-updater (`-U / --update`) featuring semver comparison and atomic script replacement without external patch dependencies.
- Native desktop notifications connected for playback start and download completion.
- Provider test suite (`test/test_providers.sh`).
- Lifetime Watch Log and Personal Anime Journal (`lib/sranime-cli/watchlog.sh`).
- `-W, --watch-log` flag to display complete chronological watch and download history with optional title filter.
- `--watch-stats` flag to calculate and display viewing analytics (episodes watched, total time, most-watched series).
- `--watch-export [json|csv]` flag to export viewing history for spreadsheets, AniList, or personal backups.
- `--clear-watch-log` flag to reset lifetime watch logs.
- Automatic event hooks logging both playback sessions and downloaded episodes.
- Comprehensive test suite for watchlog module (`test/test_watchlog.sh`).
- Dynamic library path resolution (`SRANIME_LIB_DIR`).
- Rich Terminal UI & Cover Art Previews (`lib/sranime-cli/preview.sh`).
- Interactive side preview pane in `fzf` displaying anime English & Japanese titles, format, duration, Sub/Dub counts, watch history status, and English synopsis.
- Optional terminal cover art thumbnail rendering via `chafa`.
- Watched episode badges (`✓ [Watched]`) integrated into episode selection menu.
- Toggle preview anytime with `?` or disable with `--no-preview` flag / `SRANIME_CLI_PREVIEW=0`.
- Dedicated preview test suite (`test/test_preview.sh`) with 19 automated tests.

### Fixed
- Fixed Windows fzf preview pane error (`'""11""' is not recognized`) by eliminating nested shell quotes and invoking Windows cmd shim directly with tab delimiters (`--delimiter=\t` and `--with-nth=1,3`).
- Fixed preview metadata ID extraction to support full tabbed item rows as well as individual anime slugs.
- Accelerated search responsiveness by running metadata card cache parsing asynchronously in the background.
- Added repository-root `sranime-cli.cmd` launcher for seamless Windows PowerShell/CMD execution.

### Optimized
- Accelerated MPV streaming with instant window rendering (`--force-window=immediate`), zero python yt-dlp delay on direct HLS links (`--ytdl=no`), and high-throughput HLS chunk buffer parameters (`--cache=yes --demuxer-max-bytes=100M --demuxer-readahead-secs=20`).
- Prevented Windows console lockups by adding `--no-terminal` flag to background MPV process on Windows.
- Implemented lazy-loading of secondary modules (`watchlog`, `watchlist`, `config`, `notify`) to minimize startup file I/O latency.
- Fast-pathed `curl` binary detection to eliminate repetitive PATH traversal on Windows.
- Optimized default search and episode resolution path to avoid redundant subshell nesting on Windows/MSYS2.

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
