# Prompt Configuration File
# ---- Distro Icon Setup ----
distro_icon=""
if [[ "$(uname -s)" == "Darwin" ]]; then
    distro_icon=" "
elif [[ "$(uname -s)" == "Linux" ]]; then
    if [[ -f /etc/os-release ]]; then
        distro_id=$(awk -F= '/^ID=/{print tolower($2)}' /etc/os-release | tr -d '"')
        case "$distro_id" in
            debian)  distro_icon="" ;;
            ubuntu)  distro_icon="" ;;
            fedora)  distro_icon="" ;;
            arch)    distro_icon="" ;;
            gentoo)  distro_icon="" ;;
            *)       distro_icon="" ;;
        esac
    else
        distro_icon=""
    fi
fi

# ---- PROMPT Setup ----
SPROMPT='%B%F{red}[ %F{white}'"$distro_icon"' %F{yellow}%n%F{green}@%F{blue}%m %F{magenta}%~ %F{red}]%f%b$ '
MPROMPT='%B%F{red}[ %F{white}'"$distro_icon"' %F{yellow}%n%F{green}@%F{blue}%m %F{magenta}%~ %F{red}]%f%b'$'\n''$ '

PS2="%B%{$fg[red]%}[ %F{white}PS2 %{$fg[red]%}]%{$reset_color%}$%b "

if $USE_MULTILINE_PROMPT; then
    PROMPT=${MPROMPT}
else
    PROMPT=${SPROMPT}
fi

# ---- Git Info ----
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats '%r(%b)'
zstyle ':vcs_info:git:*' actionformats '%r(%b|%a)'
zstyle ':vcs_info:git+set-message:*' hooks store-symbols

function +vi-store-symbols() {
    GIT_SYMBOLS=""

    # Only run these if HEAD exists
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
        git diff --quiet --ignore-submodules HEAD || GIT_SYMBOLS+="*"
        git diff --cached --quiet --ignore-submodules HEAD || GIT_SYMBOLS+="*"

        # Only run rev-list if upstream is set
        if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
            local stats=$(git rev-list --left-right --count @{u}...HEAD 2>/dev/null)
            local behind=$(echo $stats | awk '{print $1}')
            local ahead=$(echo $stats | awk '{print $2}')
            (( behind > 0 )) && GIT_SYMBOLS+="⇣"
            (( ahead > 0 )) && GIT_SYMBOLS+="⇡"
        fi
    fi
}

# ---- Command Timing ----
preexec() {
    CMD_START_TIME=$(date +%s)
}

function my_precmd() {
    print ""
    vcs_info
    local git_project="%F{magenta}${vcs_info_msg_0_}%f"
    local git_symbols="%F{cyan}${GIT_SYMBOLS}%f"

    local elapsed=""
    if [[ -n $CMD_START_TIME ]]; then
        local now=$(date +%s)
        local duration=$(echo "$now - $CMD_START_TIME" | bc)
        local int_duration=${duration%.*}
        if (( int_duration > 5 )); then
            elapsed="%F{yellow}took ${int_duration}s%f"
        fi
    fi

    RPROMPT="${git_project} ${git_symbols} ${elapsed}"
    TRANSIENT_PROMPT_RPROMPT="$RPROMPT"
}

precmd_functions+=( my_precmd )

# ---- Transient Prompt Support ----
typeset -g TRANSIENT_PROMPT_PROMPT=${TRANSIENT_PROMPT_PROMPT-$PROMPT}
typeset -g TRANSIENT_PROMPT_RPROMPT=${TRANSIENT_PROMPT_RPROMPT-$RPROMPT}
typeset -g TRANSIENT_PROMPT_TRANSIENT_PROMPT="%B%{$fg[red]%}[ %F{white}$distro_icon %{$fg[magenta]%}%~ %{$fg[red]%}]%{$reset_color%}$%b "
typeset -g TRANSIENT_PROMPT_TRANSIENT_RPROMPT=""
typeset -gA TRANSIENT_PROMPT_ENV
TRANSIENT_PROMPT_ENV[RPROMPT]=''

function _transient_prompt_init() {
    [[ -c /dev/null ]] || return
    zmodload zsh/system || return
    _transient_prompt_toggle_transient 0
    zle -N send-break _transient_prompt_widget-send-break
    zle -N zle-line-finish _transient_prompt_widget-zle-line-finish
    (( ${+precmd_functions} )) || typeset -ga precmd_functions
    precmd_functions+=_transient_prompt_precmd
}

function _transient_prompt_precmd() {
    TRAPINT() {
        zle && _transient_prompt_widget-zle-line-finish
        return $(( 128 + $1 ))
    }
}

function _transient_prompt_restore_prompt() {
    exec {1}>&-
    (( ${+1} )) && zle -F $1
    _transient_prompt_fd=0
    _transient_prompt_toggle_transient 0
    zle reset-prompt
    zle -R
}

function _transient_prompt_toggle_transient() {
    local -i transient
    transient=${1-0}

    if (( transient )); then
        PROMPT=$TRANSIENT_PROMPT_TRANSIENT_PROMPT
        RPROMPT=$TRANSIENT_PROMPT_TRANSIENT_RPROMPT
        return
    fi

    PROMPT=$TRANSIENT_PROMPT_PROMPT
    RPROMPT=$TRANSIENT_PROMPT_RPROMPT
}

function _transient_prompt_widget-send-break() {
    _transient_prompt_widget-zle-line-finish
    zle .send-break
}

function _transient_prompt_widget-zle-line-finish() {
    (( ! _transient_prompt_fd )) && {
        sysopen -r -o cloexec -u _transient_prompt_fd /dev/null
        zle -F $_transient_prompt_fd _transient_prompt_restore_prompt
    }

    for key in ${(k)TRANSIENT_PROMPT_ENV}; do
        value=$TRANSIENT_PROMPT_ENV[$key]
        typeset -g _transient_prompt_${key}_saved=${(P)key}
        typeset -g "$key"="$value"
    done

    _transient_prompt_toggle_transient 1
    zle && zle reset-prompt && zle -R

    local key_saved
    for key in ${(k)TRANSIENT_PROMPT_ENV}; do
        key_saved=_transient_prompt_${key}_saved
        typeset -g $key=${(P)key_saved}
        unset $key_saved
    done
}

_transient_prompt_init
unfunction -m _transient_prompt_init
