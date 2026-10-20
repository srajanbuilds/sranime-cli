# fish completion for sranime-cli

complete -c sranime-cli -s c -l continue -d "Continue watching from history"
complete -c sranime-cli -s A -l autoplay -d "Automatically play subsequent episodes continuously"
complete -c sranime-cli -l autoplay-limit -d "Limit number of consecutive autoplay episodes" -x
complete -c sranime-cli -s R -l resume -d "Resume playback from saved timestamp checkpoint"
complete -c sranime-cli -l start-time -d "Seek to exact timestamp on start" -x
complete -c sranime-cli -l show-checkpoints -d "Display active in-progress watch checkpoints"
complete -c sranime-cli -l clear-checkpoints -d "Clear all stored playback timestamp checkpoints"

complete -c sranime-cli -s d -l download -d "Download the video instead of playing it"
complete -c sranime-cli -l download-dir -d "Directory for downloaded anime files" -x -a "(__fish_complete_directories)"
complete -c sranime-cli -s D -l delete -d "Delete history"
complete -c sranime-cli -l clear-history -d "Delete history"
complete -c sranime-cli -l show-history -d "Display watch history and exit"
complete -c sranime-cli -s l -l logview -d "Show logs"
complete -c sranime-cli -s s -l syncplay -d "Use Syncplay to watch with friends"
complete -c sranime-cli -l room -d "Set Syncplay room name" -x
complete -c sranime-cli -l discord -d "Enable Discord Rich Presence"
complete -c sranime-cli -l no-discord -d "Disable Discord Rich Presence"
complete -c sranime-cli -s S -l select-nth -d "Select nth entry" -x
complete -c sranime-cli -s p -l provider -d "Specify stream provider" -x -a "hianime allanime gogo"
complete -c sranime-cli -l list-providers -d "List available stream providers"
complete -c sranime-cli -s q -l quality -d "Specify the video quality" -x -a "best worst 1080p 720p 480p 360p"
complete -c sranime-cli -s v -l vlc -d "Use VLC to play the video"
complete -c sranime-cli -s V -l version -d "Show version of the script"
complete -c sranime-cli -s h -l help -d "Show help message and exit"
complete -c sranime-cli -s e -l episode -d "Specify episode number to watch" -x
complete -c sranime-cli -s r -l range -d "Specify range of episodes to watch" -x
complete -c sranime-cli -l dub -d "Play dubbed version"
complete -c sranime-cli -l rofi -d "Use rofi instead of fzf"
complete -c sranime-cli -l dmenu -d "Use dmenu instead of fzf"
complete -c sranime-cli -l skip -d "Use ani-skip to skip intro"
complete -c sranime-cli -l no-detach -d "Do not detach player"
complete -c sranime-cli -l exit-after-play -d "Exit after playback"
complete -c sranime-cli -s N -l nextep-countdown -d "Display countdown to next episode"
complete -c sranime-cli -s U -l update -d "Update the script"
complete -c sranime-cli -l edit-config -d "Open configuration file in editor"
complete -c sranime-cli -l validate-config -d "Validate configuration file syntax"
complete -c sranime-cli -l dump-config -d "Print active configuration values and exit"
complete -c sranime-cli -l watchlist -d "Display saved anime watchlist"
complete -c sranime-cli -l watchlist-clear -d "Clear saved watchlist"
complete -c sranime-cli -s W -l watch-log -d "Display lifetime watch log history"
complete -c sranime-cli -l watch-stats -d "Display viewing statistics and analytics"
complete -c sranime-cli -l watch-export -d "Export watch log to JSON or CSV" -x -a "json csv"
complete -c sranime-cli -l clear-watch-log -d "Clear lifetime watch log"
complete -c sranime-cli -l no-preview -d "Disable rich terminal preview pane"
complete -c sranime-cli -l login -d "Authenticate with cloud anime trackers" -x -a "anilist mal"
complete -c sranime-cli -l scrobble-status -d "Display status of linked tracking accounts"
complete -c sranime-cli -l logout -d "Log out from cloud tracking services" -x -a "anilist mal"
complete -c sranime-cli -l export-mal -d "Export watch log in MyAnimeList XML format" -r
complete -c sranime-cli -l import-mal -d "Import watch history from MyAnimeList XML file" -r
complete -c sranime-cli -l nfo -d "Generate Jellyfin/Plex/Kodi .nfo metadata and artwork"
complete -c sranime-cli -l save-subs -d "Extract and save external subtitle sidecars"
complete -c sranime-cli -l queue -d "Enqueue episode for background downloading"
complete -c sranime-cli -l queue-status -d "Display background download queue status"
complete -c sranime-cli -l queue-start -d "Start background download queue daemon worker"
complete -c sranime-cli -l queue-pause -d "Pause background download queue"
complete -c sranime-cli -l queue-resume -d "Resume background download queue"
complete -c sranime-cli -l queue-clear -d "Clear items from download queue" -x -a "completed all"
complete -c sranime-cli -l sync -d "Open interactive menu with your AniList Currently Watching shows"
complete -c sranime-cli -l sync-list -d "Display your AniList Currently Watching watchlist and exit"
complete -c sranime-cli -l no-scrobble -d "Disable automatic episode tracking for this session"
complete -c sranime-cli -l doctor -d "Run system diagnostics and dependency check"
complete -c sranime-cli -l seasonal -d "Browse popular anime of broadcast season" -x
complete -c sranime-cli -l trending -d "Browse currently trending anime series"
complete -c sranime-cli -l calendar -d "Display upcoming airing schedule with countdowns"
complete -c sranime-cli -l schedule -d "Display upcoming airing schedule with countdowns"
complete -c sranime-cli -l similar -d "Discover recommendations based on anime title" -x
complete -c sranime-cli -l sub-lang -s sl -d "Preferred subtitle language" -r
complete -c sranime-cli -l audio-lang -s al -d "Preferred audio language" -r
complete -c sranime-cli -l cast -d "Cast stream to Smart TV or Chromecast" -r
complete -c sranime-cli -l cast-devices -d "Scan network for Cast devices"
complete -c sranime-cli -l web -d "Launch local LAN web companion microserver" -r
complete -c sranime-cli -l web-stop -d "Stop background web companion microserver"
complete -c sranime-cli -l web-status -d "Check status of web companion microserver"

complete -c sranime-cli -s t -l theme -d "Search and play Opening & Ending theme songs" -r
complete -c sranime-cli -l theme-type -d "Filter theme songs by OP or ED" -x -a "all op ed"
complete -c sranime-cli -s a -l audio-only -d "Stream theme audio only"
complete -c sranime-cli -l theme-download -d "Download selected theme song"
complete -c sranime-cli -l notify-airing -d "Check for upcoming simulcasts and send desktop notification"
complete -c sranime-cli -l airing-window -d "Time horizon in hours for airing alerts" -r
complete -c sranime-cli -s O -l offline -d "Browse and play downloaded anime from local vault"
complete -c sranime-cli -l local -d "Specify local vault directory for offline playback" -r
complete -c sranime-cli -l color-theme -d "Set UI color palette" -x -a "catppuccin dracula nord gruvbox tokyo-night cyberpunk default"
complete -c sranime-cli -l color-themes -d "Display gallery of terminal color palettes"
