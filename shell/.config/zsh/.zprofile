# NOTE: PATH/XDG/editor exports used to be duplicated here verbatim from
# .zshenv. .zshenv always runs *before* .zprofile on every zsh startup
# (login or not), so re-running the exact same PATH scans and exports here
# was pure redundant work on every login shell. Removed - only genuinely
# login-specific setup lives below.

# QT Theme
export QT_QPA_PLATFORMTHEME="qt6ct"

# Streaming token (Twitch Streaming)
[[ -f "$HOME/Documents/pass/twitch_token" ]] && export TWITCH_TOKEN="$(cat "$HOME/Documents/pass/twitch_token")"

# Start Hyprland
if [[ "$(tty)" = /dev/tty1 ]];then
    pgrep hyprland || start-hyprland
fi

# Start Dwm
# if [[ "$(tty)" = /dev/tty1 ]]; then
# pgrep dwm || startx
# fi
