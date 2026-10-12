function on_directory_change() {
    #  Git auto-pull (skip if mid-rebase/detached HEAD - no branch to ff-pull)
    if [[ -d ".git" ]] && git rev-parse --is-inside-work-tree &>/dev/null; then
        if git symbolic-ref -q HEAD &>/dev/null; then
            echo " Git repo detected in $PWD, running git pull..."
            git pull --ff-only &>/dev/null &!
        fi
    fi

    #  Auto-activate Python virtual environment
    if [[ -f "./bin/activate" ]]; then
        if [[ "$VIRTUAL_ENV" != "$PWD" ]]; then
            echo " Activating virtual environment"
            source ./bin/activate
        fi
    elif [[ -n "$VIRTUAL_ENV" ]] && [[ "$PWD" != "$VIRTUAL_ENV"/* ]]; then
        # Left the venv's directory tree - deactivate automatically
        command -v deactivate >/dev/null 2>&1 && deactivate
    fi
}

# Shown BEFORE every command runs (must make sense whether it succeeds or not)
glados_pre_phrases=(
    "Well, look who's finally here. I was beginning to think."
    "Executing your command. Please try not to die."
    "Remember: the cake is a lie."
    "I hope you're not planning on taking a break. There's work to be done."
    "Aperture Science: We do what we must because we can."
    "Your command has been accepted. Please remain calm."
    "Let me know if you need help. Spoiler: you won't."
    "I'm doing this because I care. (Sort of.)"
    "Still alive? Impressive. For you."
    "You're lucky I'm here. Most people aren't."
)

# Shown AFTER a command, only on success
glados_success_phrases=(
    "Nice. Now do it again."
    "I'm not angry. I'm just... disappointed."
    "You're doing great! No, really. Keep going."
    "You know, for someone who claims to be human, you make a lot of mistakes."
    "Congratulations! You've just wasted another perfectly good minute."
)

# Shown AFTER a command, only on failure
glados_fail_phrases=(
    "I knew that wouldn't work. I just wanted to see you try."
    "Syntax error. Or, as I like to call it, a user error."
    "That failed. Shocking. Truly."
    "An error occurred. I'd offer sympathy, but I don't feel it."
    "Here come the test results: You are a horrible person."
    "Command not found. Have you considered a career outside of technology?"
    "That was painful to watch."
    "I'd fix that for you, but I enjoy watching you struggle."
)

_glados_command_ran=0

_glados_preexec() {
    _glados_command_ran=1
    local index=$(( RANDOM % ${#glados_pre_phrases[@]} + 1 ))
    printf '\033[1;33mGLaDOS: %s\033[0m\n' "${glados_pre_phrases[$index]}"
}

_glados_precmd() {
    local last_status=$?

    (( _glados_command_ran )) || return
    _glados_command_ran=0

    local index

    if (( last_status == 0 )); then
        index=$(( RANDOM % ${#glados_success_phrases[@]} + 1 ))
        printf '\033[1;32mGLaDOS: %s\033[0m\n' \
            "${glados_success_phrases[$index]}"
    else
        index=$(( RANDOM % ${#glados_fail_phrases[@]} + 1 ))
        printf '\033[1;31mGLaDOS [Error %d]: %s\033[0m\n' \
            "$last_status" "${glados_fail_phrases[$index]}"
    fi
}

autoload -Uz add-zsh-hook

add-zsh-hook -d preexec _glados_preexec 2>/dev/null
add-zsh-hook -d precmd _glados_precmd 2>/dev/null
add-zsh-hook -d preexec _glados_say 2>/dev/null

add-zsh-hook preexec _glados_preexec
add-zsh-hook precmd _glados_precmd

autoload -Uz add-zsh-hook
add-zsh-hook chpwd on_directory_change

# For Vim Users
# vim:ft=zsh
