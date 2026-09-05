# Path Variables
for _pathdir in \
    "$HOME/go/bin" \
    "/usr/local/go/bin" \
    "$HOME/.cargo/bin" \
    "$HOME/.local/scripts" \
    "$HOME/.local/bin" \
    "$HOME/Applications" \
    "/usr/games"
do
    [[ -d "$_pathdir" ]] && PATH="$_pathdir:$PATH"
done
unset _pathdir

# XDG Exports
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_SCRIPTS_HOME="${XDG_SCRIPTS_HOME:-$HOME/.local/scripts}"
export XDG_SCRIPTS_DEV="${XDG_SCRIPTS_DEV:-$HOME/Scripts}"

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
export READER="zathura"
export LOCKER="hyprlock"

# Setting ZDOTDIR
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
export SDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/shell"
export PLUGINDIR="${XDG_DATA_HOME:-$HOME/.local/share}/zplugins"
