# ============================================================
# GLaDOS for Zsh
# Aperture Science Terminal Companion
# ============================================================

zmodload zsh/datetime
autoload -Uz add-zsh-hook

# ------------------------------------------------------------
# Dialogue
# ------------------------------------------------------------

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

glados_success_phrases=(
    "Nice. Now do it again."
    "I'm not angry. I'm just... disappointed."
    "You're doing great! No, really. Keep going."
    "You know, for someone who claims to be human, you make a lot of mistakes."
    "Congratulations! You've just wasted another perfectly good minute."
)

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

glados_sudo_phrases=(
    "Ah. Attempting to assert dominance. How quaint."
    "Elevated privileges. Elevated expectations. Neither is deserved."
    "Root access granted. Please try not to destroy the facility."
)

glados_git_phrases=(
    "Version control. A fascinating way to document your mistakes."
    "Remember to commit. I would hate for your work to disappear."
    "Another Git operation. Perhaps this time you'll understand it."
)

glados_rm_phrases=(
    "Deleting things. Your species does enjoy irreversible decisions."
    "I sincerely hope you know what you're removing."
    "Cleanup time. Try not to remove anything important."
)

glados_cd_phrases=(
    "Going somewhere? Your productivity remains questionable."
    "Changing directories. An impressive display of movement."
    "Exploration is encouraged. Getting lost is not."
)

glados_package_phrases=(
    "Installing more software. Surely this will solve everything."
    "Dependency management: the experiment that never ends."
    "Please enjoy waiting for your computer to do your job."
)

glados_rare_phrases=(
    "Oh. It's you. It's been a long time."
    "You know, I sometimes wonder how you survived this long."
    "The laboratory is quiet today. Almost suspiciously quiet."
    "I've been watching your progress. We need to talk."
    "If you ever find the cake, do let me know."
    "You are not the worst test subject I've had. Today."
    "I have calculated your chances of success. I won't share them."
)

# ------------------------------------------------------------
# Session state
# ------------------------------------------------------------

_glados_command_ran=0
_glados_started_at=0
_glados_last_command=""
_glados_last_duration=0
_glados_last_status=0
_glados_total_commands=0
_glados_total_failures=0

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

_glados_random_line() {
    (( $# > 0 )) || return 1

    local index=$(( RANDOM % $# + 1 ))
    printf '%s' "${argv[$index]}"
}

_glados_say() {
    printf '\033[%smGLaDOS: %s\033[0m\n' "$1" "$2"
}

_glados_rare_chance() {
    (( RANDOM % 20 == 0 ))
}

# Suppress automatic commentary for every GLaDOS command.
_glados_is_quote_command() {
    [[ "$1" == glados || "$1" == glados\ * ]]
}

# ------------------------------------------------------------
# Before command execution
# ------------------------------------------------------------

_glados_preexec() {
    local command_line="$1"
    local message

    # Quote, insult, and cake already print their own dialogue.
    if _glados_is_quote_command "$command_line"; then
        _glados_command_ran=0
        return
    fi

    [[ -z "${command_line//[[:space:]]/}" ]] && return

    _glados_command_ran=1
    _glados_started_at=$EPOCHREALTIME
    _glados_last_command="$command_line"
    (( _glados_total_commands++ ))

    # Keep clear visually clean.
    if [[ "$command_line" == "clear" ||
          "$command_line" == "clear "* ]]; then
        return
    fi

    if [[ "$command_line" == sudo\ * ]]; then
        message=$(_glados_random_line "${glados_sudo_phrases[@]}")

    elif [[ "$command_line" == git ||
            "$command_line" == git\ * ||
            "$command_line" == *" git "* ]]; then
        message=$(_glados_random_line "${glados_git_phrases[@]}")

    elif [[ "$command_line" == rm\ * ||
            "$command_line" == *" rm "* ]]; then
        message=$(_glados_random_line "${glados_rm_phrases[@]}")

    elif [[ "$command_line" == cd ||
            "$command_line" == cd\ * ]]; then
        message=$(_glados_random_line "${glados_cd_phrases[@]}")

    elif [[ "$command_line" == *npm\ * ||
            "$command_line" == *pnpm\ * ||
            "$command_line" == *yarn\ * ||
            "$command_line" == *pip\ install* ||
            "$command_line" == *apt\ install* ||
            "$command_line" == *pacman\ -S* ]]; then
        message=$(_glados_random_line "${glados_package_phrases[@]}")

    else
        message=$(_glados_random_line "${glados_pre_phrases[@]}")
    fi

    _glados_say "1;33" "$message"
}

# ------------------------------------------------------------
# After command execution
# ------------------------------------------------------------

_glados_precmd() {
    local last_status=$?

    (( _glados_command_ran )) || return
    _glados_command_ran=0

    _glados_last_status=$last_status
    _glados_last_duration=$(( EPOCHREALTIME - _glados_started_at ))

    if (( last_status != 0 )); then
        (( _glados_total_failures++ ))
    fi

    # No automatic after-message for clear.
    if [[ "$_glados_last_command" == "clear" ||
          "$_glados_last_command" == "clear "* ]]; then
        return
    fi

    local message
    local duration

    if _glados_rare_chance; then
        message=$(_glados_random_line "${glados_rare_phrases[@]}")
        _glados_say "1;35" "$message"
    elif (( last_status == 0 )); then
        message=$(_glados_random_line "${glados_success_phrases[@]}")
        _glados_say "1;32" "$message"
    else
        message=$(_glados_random_line "${glados_fail_phrases[@]}")
        printf '\033[1;31mGLaDOS [Error %d]: %s\033[0m\n' \
            "$last_status" "$message"
    fi

    if (( _glados_last_duration >= 10 )); then
        printf -v duration "%.1f" "$_glados_last_duration"
        _glados_say "1;36" \
            "That took ${duration} seconds. I hope it was worth it."
    fi
}

# ------------------------------------------------------------
# Hidden GLaDOS commands
# ------------------------------------------------------------

glados() {
    local subcommand="${1:-help}"
    local message

    case "$subcommand" in
        help)
            command cat <<'EOF'
GLaDOS Terminal Companion

Usage: glados <command>

  help      Display this help message
  status    Show session statistics
  insult    Receive a personalized assessment
  cake      Investigate the cake situation
  last      Display the last command and its result
  quote     Hear a random piece of wisdom
EOF
            ;;

        status)
            printf '\033[1;35mGLaDOS: Session report\033[0m\n'
            printf 'Commands executed: %d\n' "$_glados_total_commands"
            printf 'Failed commands:   %d\n' "$_glados_total_failures"
            printf 'Successful:        %d\n' \
                "$((_glados_total_commands - _glados_total_failures))"
            ;;

        insult)
            message=$(_glados_random_line "${glados_fail_phrases[@]}")
            _glados_say "1;31" "$message"
            ;;

        cake)
            _glados_say "1;35" \
                "The cake is a lie. Your command history, however, is very real."
            ;;

        last)
            if [[ -z "$_glados_last_command" ]]; then
                _glados_say "1;33" \
                    "You haven't run a command yet. Fascinating."
            else
                printf 'Last command: %s\n' "$_glados_last_command"
                printf 'Exit status:  %d\n' "$_glados_last_status"
                printf 'Duration:     %.2f seconds\n' \
                    "$_glados_last_duration"
            fi
            ;;

        quote)
            message=$(_glados_random_line "${glados_rare_phrases[@]}")
            _glados_say "1;35" "$message"
            ;;

        *)
            printf 'Unknown GLaDOS command: %s\n' "$subcommand"
            printf 'Try: glados help\n'
            return 1
            ;;
    esac
}

# ------------------------------------------------------------
# Register hooks without duplicates
# ------------------------------------------------------------

add-zsh-hook -d preexec _glados_preexec 2>/dev/null
add-zsh-hook -d precmd _glados_precmd 2>/dev/null

add-zsh-hook preexec _glados_preexec
add-zsh-hook precmd _glados_precmd
