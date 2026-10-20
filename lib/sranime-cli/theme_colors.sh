#!/bin/sh
# sranime-cli terminal color theme engine
# Provides curated modern color palettes for fzf, preview cards, and banner art.
#
# Supported Themes:
#   - catppuccin (Mocha)
#   - dracula
#   - nord
#   - gruvbox
#   - tokyo-night
#   - cyberpunk
#   - default

theme_colors_list() {
    printf "catppuccin
dracula
nord
gruvbox
tokyo-night
cyberpunk
default
"
}

theme_colors_valid() {
    _cand="$1"
    case "$_cand" in
        catppuccin|dracula|nord|gruvbox|tokyo-night|cyberpunk|default) return 0 ;;
        *) return 1 ;;
    esac
}

theme_colors_fzf_opts() {
    _thm="${1:-default}"
    case "$_thm" in
        catppuccin)
            printf -- "--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 --color=selected-bg:#45475a --color=border:#b4befe"
            ;;
        dracula)
            printf -- "--color=bg+:#44475a,bg:#282a36,spinner:#ffb86c,hl:#bd93f9 --color=fg:#f8f8f2,header:#50fa7b,info:#ffb86c,pointer:#ff79c6 --color=marker:#ff79c6,fg+:#f8f8f2,prompt:#50fa7b,hl+:#bd93f9 --color=border:#bd93f9"
            ;;
        nord)
            printf -- "--color=bg+:#3b4252,bg:#2e3440,spinner:#88c0d0,hl:#81a1c1 --color=fg:#eceff4,header:#5e81ac,info:#88c0d0,pointer:#81a1c1 --color=marker:#ebcb8b,fg+:#eceff4,prompt:#81a1c1,hl+:#81a1c1 --color=border:#88c0d0"
            ;;
        gruvbox)
            printf -- "--color=bg+:#3c3836,bg:#282828,spinner:#fabd2f,hl:#fe8019 --color=fg:#ebdbb2,header:#fb4934,info:#fabd2f,pointer:#fe8019 --color=marker:#b8bb26,fg+:#ebdbb2,prompt:#fabd2f,hl+:#fe8019 --color=border:#fe8019"
            ;;
        tokyo-night)
            printf -- "--color=bg+:#283457,bg:#1a1b26,spinner:#7dcfff,hl:#bb9af7 --color=fg:#c0caf5,header:#7aa2f7,info:#7dcfff,pointer:#bb9af7 --color=marker:#9ece6a,fg+:#c0caf5,prompt:#7aa2f7,hl+:#bb9af7 --color=border:#7aa2f7"
            ;;
        cyberpunk)
            printf -- "--color=bg+:#1a103c,bg:#000b1e,spinner:#00f0ff,hl:#ff003c --color=fg:#00f0ff,header:#fcee0a,info:#ff003c,pointer:#fcee0a --color=marker:#00f0ff,fg+:#ffffff,prompt:#00f0ff,hl+:#ff003c --color=border:#fcee0a"
            ;;
        *)
            # Standard neutral fallback
            printf ""
            ;;
    esac
}

theme_colors_set() {
    _thm="${1:-default}"
    case "$_thm" in
        catppuccin)
            _tc_border="[38;2;180;190;254m"   # Lavender
            _tc_title="[1;38;2;203;166;247m"  # Mauve bold
            _tc_sub="[38;2;245;194;231m"    # Pink
            _tc_accent="[38;2;116;199;236m"  # Sapphire
            _tc_label="[1;38;2;249;226;175m" # Yellow bold
            _tc_success="[38;2;166;227;161m" # Green
            _tc_warning="[38;2;250;179;135m" # Peach
            _tc_danger="[38;2;243;139;168m"  # Red
            _tc_muted="[38;2;147;153;178m"   # Overlay0
            _tc_reset="[0m"
            ;;
        dracula)
            _tc_border="[38;2;189;147;249m"   # Purple
            _tc_title="[1;38;2;80;250;123m"   # Green bold
            _tc_sub="[38;2;255;121;198m"    # Pink
            _tc_accent="[38;2;139;233;253m"  # Cyan
            _tc_label="[1;38;2;255;184;108m" # Orange bold
            _tc_success="[38;2;80;250;123m"  # Green
            _tc_warning="[38;2;241;250;140m" # Yellow
            _tc_danger="[38;2;255;85;85m"    # Red
            _tc_muted="[38;2;98;114;164m"    # Comment
            _tc_reset="[0m"
            ;;
        nord)
            _tc_border="[38;2;136;192;208m"   # Frost teal
            _tc_title="[1;38;2;129;161;193m"  # Frost blue bold
            _tc_sub="[38;2;143;188;187m"    # Frost green
            _tc_accent="[38;2;94;129;172m"   # Frost deep blue
            _tc_label="[1;38;2;235;203;139m" # Yellow bold
            _tc_success="[38;2;163;190;140m" # Aurora Green
            _tc_warning="[38;2;208;135;112m" # Aurora Orange
            _tc_danger="[38;2;191;97;106m"   # Aurora Red
            _tc_muted="[38;2;76;86;106m"     # Polar Night 3
            _tc_reset="[0m"
            ;;
        gruvbox)
            _tc_border="[38;2;254;128;25m"    # Orange
            _tc_title="[1;38;2;250;189;47m"   # Yellow bold
            _tc_sub="[38;2;211;134;155m"    # Purple
            _tc_accent="[38;2;142;192;124m"  # Aqua
            _tc_label="[1;38;2;251;73;52m"   # Red bold
            _tc_success="[38;2;184;187;38m"  # Green
            _tc_warning="[38;2;250;189;47m"  # Yellow
            _tc_danger="[38;2;251;73;52m"    # Red
            _tc_muted="[38;2;146;131;116m"   # Gray
            _tc_reset="[0m"
            ;;
        tokyo-night)
            _tc_border="[38;2;122;162;247m"   # Blue
            _tc_title="[1;38;2;187;154;247m"  # Magenta bold
            _tc_sub="[38;2;125;207;255m"    # Teal
            _tc_accent="[38;2;224;175;104m"  # Orange/Yellow
            _tc_label="[1;38;2;122;162;247m" # Blue bold
            _tc_success="[38;2;158;206;106m" # Green
            _tc_warning="[38;2;224;175;104m" # Orange
            _tc_danger="[38;2;247;118;142m"  # Red
            _tc_muted="[38;2;86;95;137m"     # Dark Slate
            _tc_reset="[0m"
            ;;
        cyberpunk)
            _tc_border="[38;2;252;238;10m"    # Neon Yellow
            _tc_title="[1;38;2;0;240;255m"    # Electric Cyan bold
            _tc_sub="[38;2;255;0;60m"       # Neon Pink
            _tc_accent="[38;2;252;238;10m"   # Neon Yellow
            _tc_label="[1;38;2;255;0;60m"    # Neon Pink bold
            _tc_success="[38;2;0;255;102m"   # Neon Green
            _tc_warning="[38;2;255;153;0m"   # Neon Amber
            _tc_danger="[38;2;255;0;60m"     # Neon Red
            _tc_muted="[38;2;0;102;153m"     # Deep Blue
            _tc_reset="[0m"
            ;;
        *)
            # Standard ANSI colors (backward compatible)
            _tc_border="[1;36m"
            _tc_title="[1;37m"
            _tc_sub="[0;35m"
            _tc_accent="[1;36m"
            _tc_label="[1;33m"
            _tc_success="[1;32m"
            _tc_warning="[1;33m"
            _tc_danger="[1;31m"
            _tc_muted="[0;90m"
            _tc_reset="[0m"
            ;;
    esac
}

theme_colors_print_gallery() {
    printf "====================================================
"
    printf "  sranime-cli Terminal Color Theme Gallery
"
    printf "====================================================

"

    for _t in catppuccin dracula nord gruvbox tokyo-night cyberpunk default; do
        theme_colors_set "$_t"
        printf "%b[■] Theme: %-12s%b  Border: %b====%b  Title: %b%s%b  Label: %b[BADGE]%b  Muted: %b(sample)%b
" \
            "$_tc_title" "$_t" "$_tc_reset" \
            "$_tc_border" "$_tc_reset" \
            "$_tc_title" "Anime Title" "$_tc_reset" \
            "$_tc_label" "$_tc_reset" \
            "$_tc_muted" "$_tc_reset"
    done
    printf "
Usage: sranime-cli --color-theme <name> (or add color_theme="name" in sranime-cli.conf)
"
}
