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

if [[ -d "$HOME/.local/share/bob/nvim-bin" ]]; then
    PATH="$HOME/.local/share/bob/nvim-bin:$PATH"
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
export PAGER="moar"
export MANPAGER="moar"
export TERM="xterm-256color"
export COLORTERM="truecolor"
export OPENER="xdg-open"
export BROWSER="qutebrowser"
export TERMINAL="st"
export READER="zathura"
export TUIF="lf"
export GUIF="thunar"
export GEDIT="neovide"
export GMUSIC="superlaunch"
export READER="zathura"
export LOCKER="slock"

# Setting ZDOTDIR
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
export SDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/shell"

# QT Theme
export QT_QPA_PLATFORMTHEME="qt6ct"

# Bitwarden
[[ -f "$HOME/Documents/pass/clientid" ]] && export BW_CLIENTID="$(cat "$HOME/Documents/pass/clientid")"
[[ -f "$HOME/Documents/pass/clientsec" ]] && export BW_CLIENTSECRET="$(cat "$HOME/Documents/pass/clientsec")"
[[ -f "$HOME/Documents/pass/userpass" ]] && export BW_PASSWORD="$(cat "$HOME/Documents/pass/userpass")"

# RustUp
[[ -f "$HOME/.cargo/env" ]] || . "$HOME/.cargo/env"

# Start WM
if [[ "$(tty)" = /dev/tty1 ]];then
    pgrep dwm || startx
fi
