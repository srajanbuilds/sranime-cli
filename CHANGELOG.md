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
