# fish completion for sranime-cli

complete -c sranime-cli -s c -l continue -d "Continue watching from history"
complete -c sranime-cli -s d -l download -d "Download the video instead of playing it"
complete -c sranime-cli -s D -l delete -d "Delete history"
complete -c sranime-cli -s l -l logview -d "Show logs"
complete -c sranime-cli -s s -l syncplay -d "Use Syncplay to watch with friends"
complete -c sranime-cli -s S -l select-nth -d "Select nth entry" -x
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
complete -c sranime-cli -l dump-config -d "Print active configuration values and exit"
