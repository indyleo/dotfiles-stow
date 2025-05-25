# Get distro icon
distro_icon=""

if [[ "$(uname -s)" == "Darwin" ]]; then
    distro_icon=" "
elif [[ "$(uname -s)" == "Linux" ]]; then
    if [[ -f /etc/os-release ]]; then
        # Get distro ID in lowercase
        distro_id=$(awk -F= '/^ID=/{print tolower($2)}' /etc/os-release | tr -d '"')

        case "$distro_id" in
            debian)
                distro_icon=""
                ;;
            ubuntu)
                distro_icon=""
                ;;
            fedora)
                distro_icon=""
                ;;
            arch)
                distro_icon=""
                ;;
            gentoo)
                distro_icon=""
                ;;
            *)
                distro_icon=""
                ;;
        esac
    else
        distro_icon=""
    fi
fi


# PS1 prompt
PS1="%B%{$fg[red]%}[ %F{white}$distro_icon %f%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$reset_color%}$%b "


autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git

# Only get the base project and branch — no symbols here
zstyle ':vcs_info:git:*' formats '%r(%b)'
zstyle ':vcs_info:git:*' actionformats '%r(%b|%a)'

# Set up symbols manually
zstyle ':vcs_info:git+set-message:*' hooks store-symbols

function +vi-store-symbols() {
    # Reset global for each precmd
    GIT_SYMBOLS=""

    # Check for changes
    git diff --quiet --ignore-submodules HEAD || GIT_SYMBOLS+="*"
    git diff --cached --quiet --ignore-submodules HEAD || GIT_SYMBOLS+="*"

    # Check for behind/ahead
    local stats=$(git rev-list --left-right --count @{u}...HEAD 2>/dev/null)
    local behind=$(echo $stats | awk '{print $1}')
    local ahead=$(echo $stats | awk '{print $2}')

    (( behind > 0 )) && GIT_SYMBOLS+="⇣"
    (( ahead > 0 )) && GIT_SYMBOLS+="⇡"
}

# Track command start time
preexec() {
    CMD_START_TIME=$(date +%s)
}

# Build RPROMPT
precmd() {
    print ""
    vcs_info

    local elapsed=""
    if [[ -n $CMD_START_TIME ]]; then
        local now=$(date +%s)
        # Calculate float duration
        local duration=$(echo "$now - $CMD_START_TIME" | bc)
        # Convert to integer seconds by truncating decimals
        local duration_int=${duration%.*}
        if (( duration_int > 5 )); then
            elapsed="%F{yellow}took ${duration_int}s%f"
        fi
    fi

    # Combine parts with separate colors
    local git_project="%F{magenta}${vcs_info_msg_0_}%f"
    local git_symbols="%F{cyan}${GIT_SYMBOLS}%f"

    RPROMPT="${git_project} ${git_symbols} ${elapsed}"
}
