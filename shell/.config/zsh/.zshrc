# Add to top of .zshrc to profile:
# zmodload zsh/zprof

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
# NOTE: fpath must be extended *before* compinit runs, otherwise the added
# completion functions aren't picked up until the next fresh shell.
fpath+="$PLUGINDIR/zsh-completions/src"

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zmodload zsh/complist

# Cache the completion dump and only rebuild it once a day instead of
# rescanning fpath on every single shell startup.
autoload -Uz compinit
_zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump-zsh"
if [[ -n ${_zcompdump}(#qN.mh+24) ]]; then
    compinit -C -d "$_zcompdump"
else
    compinit -d "$_zcompdump"
fi
unset _zcompdump
_comp_options+=(globdots)		# Include hidden files.

# Cached completions for tools that generate them dynamically.
# Avoids spawning gh/rustup/rbw on every shell startup - only regenerates
# the cache once a day (or if missing).
_load_gen_completion() {
    local cmd="$1" gen_args="$2"
    command -v "$cmd" >/dev/null 2>&1 || return
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-completions"
    local cache="$cache_dir/_$cmd"
    mkdir -p "$cache_dir"
    if [[ ! -s "$cache" || -n ${cache}(#qN.mh+24) ]]; then
        ${=cmd} ${=gen_args} >| "$cache" 2>/dev/null
    fi
    [[ -s "$cache" ]] && source "$cache"
}
_load_gen_completion gh "completion -s zsh"
_load_gen_completion rustup "completions zsh"
_load_gen_completion rbw "gen-completions zsh"
unfunction _load_gen_completion

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
autoload -Uz edit-command-line; zle -N edit-command-line
bindkey '^e' edit-command-line

# Load aliases, functions, and hooks if exists.
[[ -f "$SDOTDIR/alias.zsh" ]] && source "$SDOTDIR/alias.zsh"
[[ -f "$SDOTDIR/function.zsh" ]] && source "$SDOTDIR/function.zsh"
[[ -f "$SDOTDIR/hooks.zsh" ]] && source "$SDOTDIR/hooks.zsh"

# Oh my posh
command -v oh-my-posh >/dev/null 2>&1 && eval "$(oh-my-posh --init --shell zsh --config ~/.config/ohmyposh/base.toml)"

# Bindkeys
bindkey -s '^x' 'lc\n'
bindkey -s '^v' 'chtsh\n'
if [[ -z "$WEZTERM_PANE" ]]; then
    bindkey -s '^g' 'fzftmux\n'
fi

# Zoxide
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh --cmd cd)"

# Fzf
# CTRL-t = fzf select
# CTRL-r = fzf history
# ALT-c  = fzf cd
command -v fzf >/dev/null 2>&1 && eval "$(fzf --zsh)"

# ZVM
ZVM_SYSTEM_CLIPBOARD_ENABLED=true

# Loading zsh plugins (LAST)
source $PLUGINDIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
source $PLUGINDIR/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
source $PLUGINDIR/zsh-autopair/autopair.zsh 2>/dev/null
source $PLUGINDIR/zsh-history-substring-search/zsh-history-substring-search.zsh 2>/dev/null
source $PLUGINDIR/zsh-you-should-use/you-should-use.plugin.zsh 2>/dev/null
source $PLUGINDIR/zsh-vi-mode/zsh-vi-mode.plugin.zsh 2>/dev/null

# Search history
# NOTE: these bind to widgets defined by zsh-history-substring-search, so
# they must come after that plugin is sourced above (previously they were
# bound earlier in the file, before the widgets existed).
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# Fastfetch after full init (fixes column width in WezTerm splits)
_fastfetch_once() {
    if [[ -n "$WEZTERM_PANE" ]]; then
        # Give WezTerm time to send SIGWINCH with the real split dimensions
        sleep 0.15
    fi
    fastfetch
    precmd_functions=("${(@)precmd_functions:#_fastfetch_once}")
}
precmd_functions+=(_fastfetch_once)

# Add to bottom:
# zprof > ~/.zprof
