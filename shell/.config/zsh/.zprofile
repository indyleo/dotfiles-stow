# Path Variables
if [[ -d "$HOME/go/bin" ]]; then
    PATH="$HOME/go/bin:$PATH"
fi

if [[ -d "/usr/local/go/bin" ]]; then
    PATH="/usr/local/go/bin:$PATH"
fi

if [[ -d "$HOME/.cargo/bin" ]]; then
    PATH="$HOME/.cargo/bin:$PATH"
fi

if [[ -d "$HOME/.local/scripts" ]]; then
    PATH="$HOME/.local/scripts:$PATH"
fi

if [[ -d "$HOME/.local/bin" ]]; then
    PATH="$HOME/.local/bin:$PATH"
fi

if [[ -d "$HOME/Applications" ]]; then
    PATH="$HOME/Applications:$PATH"
fi

if [[ -d "/usr/games" ]]; then
    PATH="/usr/games:$PATH"
fi

# XDG Exports
if [[ -z "$XDG_CONFIG_HOME" ]]; then
    export XDG_CONFIG_HOME="$HOME/.config"
fi

if [[ -z "$XDG_DATA_HOME" ]]; then
    export XDG_DATA_HOME="$HOME/.local/share"
fi

if [[ -z "$XDG_STATE_HOME" ]]; then
    export XDG_STATE_HOME="$HOME/.local/state"
fi

if [[ -z "$XDG_CACHE_HOME" ]]; then
    export XDG_CACHE_HOME="$HOME/.cache"
fi

if [[ -z "$XDG_SCRIPTS_HOME" ]]; then
    export XDG_SCRIPTS_HOME="$HOME/.local/scripts"
fi

if [[ -z "$XDG_SCRIPTS_DEV" ]]; then
    export XDG_SCRIPTS_DEV="$HOME/Scripts"
fi

# Some Nice Exports
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="moor"
export MANPAGER="moor"
export TERM="xterm-256color"
export COLORTERM="truecolor"
export OPENER="xdg-open"
export BROWSER="librewolf"
export TERMINAL="alacritty"
export TUIF="lf"
export GUIF="thunar"
export GEDIT="neovide"
export READER="zathura"
export LOCKER="hyprlock"

# Setting ZDOTDIR
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
export SDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/shell"
export PLUGINDIR="${XDG_DATA_HOME:-$HOME/.local/share}/zplugins"

# QT Theme
export QT_QPA_PLATFORMTHEME="qt6ct"

# Bitwarden
[[ -f "$HOME/Documents/pass/clientid" ]] && export BW_CLIENTID="$(cat "$HOME/Documents/pass/clientid")"
[[ -f "$HOME/Documents/pass/clientsec" ]] && export BW_CLIENTSECRET="$(cat "$HOME/Documents/pass/clientsec")"
[[ -f "$HOME/Documents/pass/userpass" ]] && export BW_PASSWORD="$(cat "$HOME/Documents/pass/userpass")"

# Gurk (Signal TUI)
[[ -f "$HOME/Documents/pass/gurkpass" ]] && export GURK_PASSPHRASE="$(cat "$HOME/Documents/pass/gurkpass")"

# Twt (Twich Chat TUI)
[[ -f "$HOME/Documents/pass/twt" ]] && export TWT_TOKEN="$(cat "$HOME/Documents/pass/twt")"

# Streaming token (Twich Streaming)
[[ -f "$HOME/Documents/pass/twitch_token" ]] && export TWITCH_TOKEN="$(cat "$HOME/Documents/pass/twitch_token")"

# Discordo (Discord TUI)
[[ -f "$HOME/Documents/pass/discord" ]] && export DISCORDO_TOKEN="$(cat "$HOME/Documents/pass/discord")"

# Start WM
if [[ "$(tty)" = /dev/tty1 ]];then
    pgrep hyprland || hyprland
fi
