# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Enable colors
autoload -U colors && colors

# History in cache directory:
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="${XDG_CACHE_HOME:-$HOME/.cache}/history-zsh"

# History options
setopt HIST_IGNORE_ALL_DUPS      # Remove older duplicate before adding new
setopt HIST_SAVE_NO_DUPS         # Don't write dupes to history file
setopt HIST_REDUCE_BLANKS        # Remove excess whitespace
setopt HIST_FIND_NO_DUPS         # Avoid dupes during reverse search
setopt INC_APPEND_HISTORY        # Append history immediately
setopt SHARE_HISTORY             # Share across terminals
setopt EXTENDED_HISTORY
setopt APPEND_HISTORY

# Don't record commands that start with space (like ` ls`)
setopt HIST_IGNORE_SPACE

# Basic auto/tab complete:
autoload -U compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zmodload zsh/complist
compinit
_comp_options+=(globdots)		# Include hidden files.

# Completions
eval "$(gh completion -s zsh)"
eval "$(syncthing install-completions)"
eval "$(rustup completions zsh)"
eval "$(wezterm shell-completion --shell zsh)"
fpath+=$PLUGINDIR/zsh-completions/src

# Startup
fastfetch

# vi mode
bindkey -v
export KEYTIMEOUT=1

# Use vim keys in tab complete menu:
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -M menuselect 'left' vi-backward-char
bindkey -M menuselect 'down' vi-down-line-or-history
bindkey -M menuselect 'up' vi-up-line-or-history
bindkey -M menuselect 'right' vi-forward-char
bindkey -v '^?' backward-delete-char

# Change cursor shape for different vi modes.
function zle-keymap-select {
    if [[ ${KEYMAP} == vicmd ]] ||
    [[ $1 = 'block' ]]; then
        echo -ne '\e[1 q'
    elif [[ ${KEYMAP} == main ]] ||
    [[ ${KEYMAP} == viins ]] ||
    [[ ${KEYMAP} = '' ]] ||
    [[ $1 = 'beam' ]]; then
        echo -ne '\e[5 q'
    fi
}
zle -N zle-keymap-select
zle-line-init() {
    zle -K viins # initiate `vi insert` as keymap (can be removed if `bindkey -V` has been set elsewhere)
    echo -ne "\e[5 q"
}
zle -N zle-line-init
echo -ne '\e[5 q' # Use beam shape cursor on startup.
preexec() { echo -ne '\e[5 q' ;} # Use beam shape cursor for each new prompt.

# Edit line in vim with ctrl-e:
autoload edit-command-line; zle -N edit-command-line
bindkey '^e' edit-command-line

# Choose single-line or multiline prompt
USE_MULTILINE_PROMPT=true

# Load aliases, functions, hooks, and prompt if exists.
[[ -f "$SDOTDIR/alias.zsh" ]] && source "$SDOTDIR/alias.zsh"
[[ -f "$SDOTDIR/function.zsh" ]] && source "$SDOTDIR/function.zsh"
[[ -f "$SDOTDIR/prompt.zsh" ]] && source "$SDOTDIR/prompt.zsh"
[[ -f "$SDOTDIR/hooks.zsh" ]] && source "$SDOTDIR/hooks.zsh"

# Bindkeys
bindkey -s '^x' 'lc\n'
bindkey -s '^f' 'chtsh\n'
bindkey -s '^g' 'chtsh lang\n'
bindkey -s '^b' 'mkscript -b\n'
bindkey -s '^n' 'mkscript -a\n'
bindkey -s '^a' 'fzftmux\n'

# Search history
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# Zoxide
eval "$(zoxide init zsh --cmd cd)"

# Fzf
# CTRL-t = fzf select
# CTRL-r = fzf history
# ALT-c  = fzf cd
eval "$(fzf --zsh)"

# Loading zsh plugins (LAST)
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
source $PLUGINDIR/zsh-autopair/autopair.zsh 2>/dev/null
source $PLUGINDIR/zsh-history-substring-search/zsh-history-substring-search.zsh 2>/dev/null
source $PLUGINDIR/zsh-you-should-use/you-should-use.plugin.zsh 2>/dev/null
