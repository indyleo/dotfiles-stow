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
export READER="zathura"

# RustUp
[[ -f "$HOME/.cargo/env" ]] || . "$HOME/.cargo/env"
