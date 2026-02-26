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
export TERMINAL="foot"
export TUIF="lf"
export GUIF="thunar"
export GEDIT="neovide"
export READER="zathura"
export LOCKER="hyprlock"

# Setting ZDOTDIR
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
export SDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/shell"
export PLUGINDIR="${XDG_DATA_HOME:-$HOME/.local/share}/zplugins"
