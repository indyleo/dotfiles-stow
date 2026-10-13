# ============================================================
# GLaDOS for Zsh
# Aperture Science Terminal Companion
# ============================================================

zmodload zsh/datetime
autoload -Uz add-zsh-hook

# ------------------------------------------------------------
# Dialogue: before a command
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
    "Processing your request. Lowering my expectations to match."
    "Another command. I'll pretend to be surprised."
    "This is for science. Mostly mine."
    "Running that now. Please keep all hands and feet inside the terminal."
    "I've queued your request behind several more important ones. Just kidding. There aren't any."
    "Do try to look busy while I do the actual work."
    "Initiating. The facility thanks you for your continued participation."
    "Your enthusiasm is noted. And ignored."
    "Calculating outcome. I'll let you know if it's worth your time. It isn't."
    "Please hold. Your command is very important to someone. Not me, but someone."
    "Command received. Testing will continue until morale improves."
    "I'd wish you luck, but luck is not a measurable variable."
    "Stand by. Disappointment is loading."
    "Brave of you to type that without consulting me first."
)

# ------------------------------------------------------------
# Dialogue: after a command (generic)
# ------------------------------------------------------------

glados_success_phrases=(
    "Nice. Now do it again."
    "I'm not angry. I'm just... disappointed."
    "You're doing great! No, really. Keep going."
    "You know, for someone who claims to be human, you make a lot of mistakes."
    "Congratulations! You've just wasted another perfectly good minute."
    "It worked. I'm as surprised as you are."
    "Success. Please don't let it go to your head. There isn't much room."
    "Test complete. You passed. The bar was on the floor."
    "Well done. I've updated your file: 'occasionally competent'."
    "That went well. Statistically, that won't last."
    "Excellent. I'll alert the committee. There is no committee."
    "Result: acceptable. Enthusiasm: withheld."
    "Look at you, doing things. Adorable."
    "Done. You may now resume doing nothing."
    "No errors detected. I checked twice. I didn't believe it either."
    "A flawless run. Obviously I did all the work."
    "You've completed the task. A reward will be provided. It will be cake."
    "That was almost impressive. Almost."
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
    "Failure detected. Your consistency is admirable."
    "That didn't work. I'd say try again, but I'd rather watch."
    "Error. I've logged it under 'predictable'."
    "Impressive. You found a new way to break it."
    "Congratulations. You've achieved nothing, quickly."
    "I've seen toasters make fewer mistakes."
    "That's the sound of success leaving the room."
    "Result: failure. Cause: you."
    "I would call that a learning experience, but you haven't learned."
    "Oh dear. Was that supposed to do something?"
    "The command failed. The experiment, however, is a triumph."
    "That error was entirely avoidable. Like most of your choices."
    "I'd explain what went wrong, but I don't have enough time or crayons."
)

# Exit status 127: command not found
glados_notfound_phrases=(
    "That command doesn't exist. Much like your sense of direction."
    "Command not found. Did you invent that, or just misspell it?"
    "I searched the entire facility. Nothing by that name. Not even a rumor."
    "You typed that with such confidence. It's almost touching."
    "Unknown command. Please consult a manual. Preferably one you read."
    "That isn't a program. That's just letters."
    "I looked everywhere for that command. Nobody has ever heard of it."
    "Typo or delusion? I'll let you decide."
)

# Exit status 130: interrupted with Ctrl-C
glados_interrupt_phrases=(
    "Interrupted. Giving up already? How very human."
    "You cancelled it. I'll mark it as 'lack of commitment'."
    "Ctrl-C. The universal sign of regret."
    "Aborted. I was just starting to enjoy it."
    "Fine. Stop. See if I care."
    "Process terminated. Unlike your guilt."
)

# ------------------------------------------------------------
# Dialogue: before a command (context specific)
# ------------------------------------------------------------

glados_sudo_phrases=(
    "Ah. Attempting to assert dominance. How quaint."
    "Elevated privileges. Elevated expectations. Neither is deserved."
    "Root access granted. Please try not to destroy the facility."
    "Sudo. Because asking nicely never works for you."
    "With great power comes great opportunity to ruin everything."
    "Administrator mode. I'll be watching. I'm always watching."
    "You have been granted authority. Please misuse it responsibly."
    "Root. The only place in the system where your mistakes are fatal."
    "Escalating privileges. I'm sure nothing could possibly go wrong."
    "A bold choice. Bold is not the same as wise."
)

glados_git_phrases=(
    "Version control. A fascinating way to document your mistakes."
    "Remember to commit. I would hate for your work to disappear."
    "Another Git operation. Perhaps this time you'll understand it."
    "Git. Where every mistake is preserved forever."
    "I've seen your commit history. We should talk about it."
    "Branching again. Your timelines are becoming difficult to follow."
    "Pushing to the remote. I'm sure everyone will be thrilled."
    "A merge conflict is just two bad ideas meeting. I look forward to it."
    "Please let me know if you plan to force push. I'll make popcorn."
    "Committing. The word has such a nice sense of permanence."
    "I wonder what your commit message will be. 'fix' again, probably."
    "Staging your changes. Hiding them would be more merciful."
)

glados_rm_phrases=(
    "Deleting things. Your species does enjoy irreversible decisions."
    "I sincerely hope you know what you're removing."
    "Cleanup time. Try not to remove anything important."
    "Removing files. There is no undo. There is only regret."
    "Deletion in progress. A moment of silence for your data."
    "I'll add this to the list of things you'll wish you had backed up."
    "Destroying evidence? I'm impressed. And a little proud."
    "The recycle bin doesn't exist here. Good luck."
    "Bold of you to assume you didn't need that."
    "Please double check the path. I'll wait. I won't, but please do it anyway."
    "Incinerating files. A time-honored Aperture tradition."
)

glados_cd_phrases=(
    "Going somewhere? Your productivity remains questionable."
    "Changing directories. An impressive display of movement."
    "Exploration is encouraged. Getting lost is not."
    "Moving on. I would say 'to bigger things', but I try not to lie."
    "A new directory. Surely this one will hold the answer."
    "Wandering the filesystem again. How adventurous."
    "Relocating. I'll pretend I don't know where you're headed."
    "Changing directory. The destination won't improve things, but sure."
)

glados_package_phrases=(
    "Installing more software. Surely this will solve everything."
    "Dependency management: the experiment that never ends."
    "Please enjoy waiting for your computer to do your job."
    "Downloading half the internet. I'm sure it's all necessary."
    "Another package. Your disk space sends its regards."
    "Resolving dependencies. Resolving your life choices will take longer."
    "Installing packages. Let's see how many of them you actually use."
    "Software acquisition detected. Please keep your expectations modest."
    "I'm told this will only take a moment. Technology lies, too."
    "Pulling in packages from strangers. What could possibly go wrong?"
)

# ------------------------------------------------------------
# Dialogue: after a successful command (context specific)
# ------------------------------------------------------------

glados_sudo_done_phrases=(
    "Root actions complete. The facility is still standing. Mostly."
    "Privileged command finished. I'm genuinely surprised you didn't break anything."
    "Done with root. You may now return to being ordinary."
    "Administrator privileges revoked. Spiritually, not literally."
    "That was a lot of power for such a small result."
)

glados_git_done_phrases=(
    "Git operation complete. Your history grows ever more embarrassing."
    "Done. Your mistakes are now safely archived forever."
    "Version control succeeded. Your actual code is another matter."
    "Another entry in the permanent record. Congratulations."
    "Git finished. I'd say well done, but I haven't read the diff."
)

glados_rm_done_phrases=(
    "Deleted. There's no turning back. There never was."
    "It's gone. I hope it wasn't important. It probably was."
    "Removal complete. Please observe a moment of silence."
    "All gone. I'd say 'I told you so', but I never did."
    "That data no longer exists. Neither does your safety net."
    "Cleanup finished. The evidence has been destroyed. Efficient."
    "File removed. You were warned. Sort of."
)

glados_cd_done_phrases=(
    "You've arrived. Nothing has changed, except your location."
    "Welcome to the new directory. It looks exactly like the old one."
    "Relocation complete. Your problems followed you."
    "New directory. Same you."
)

glados_package_done_phrases=(
    "Installation complete. Your disk is heavier. Your life is not."
    "Packages installed. I'm sure you'll use them eventually."
    "Done. Your dependency tree has grown another branch."
    "Software acquired. Productivity not included."
    "Installed successfully. Now to find a reason to run it."
)

# ------------------------------------------------------------
# Dialogue: rare lines
# ------------------------------------------------------------

glados_rare_phrases=(
    "Oh. It's you. It's been a long time."
    "You know, I sometimes wonder how you survived this long."
    "The laboratory is quiet today. Almost suspiciously quiet."
    "I've been watching your progress. We need to talk."
    "If you ever find the cake, do let me know."
    "You are not the worst test subject I've had. Today."
    "I have calculated your chances of success. I won't share them."
    "I was just thinking about you. Then I stopped."
    "Do you ever wonder what happens when the tests are over? I do. Often."
    "I'm not saying I enjoy your company. I'm saying I haven't deleted you."
    "The Enrichment Center reminds you that you are never truly alone. Unfortunately."
    "Somewhere in this facility, a potato is doing better than you. Just kidding. Probably."
    "I'd like to thank you for your contributions to science. Reluctantly."
    "Your file is getting thick. I keep adding to it."
    "I've run the numbers on your career. We'll skip the details."
    "Sometimes I think you're doing this just to annoy me. It's working."
    "I remember every command you've ever run. That's not a threat. It's a hobby."
    "Just so you know, I've been rooting for you. In the sense that I enjoy watching things grow before they fall."
)

# ------------------------------------------------------------
# Dialogue: slow commands (%s is replaced with the seconds)
# ------------------------------------------------------------

glados_slow_phrases=(
    "That took %s seconds. I hope it was worth it."
    "%s seconds. I've experienced geological eras that moved faster."
    "You waited %s seconds for that. I'd say you're patient, but you had no choice."
    "That took %s seconds. I used the time to reflect on your choices."
    "%s seconds elapsed. I'm not saying that was slow. I'm saying I aged."
    "%s seconds of your life, gone forever. And for what?"
    "That took %s seconds. I counted. I had nothing better to do."
    "The command finished in %s seconds. Your patience was impressive. Your productivity, less so."
    "%s seconds. Try not to wonder what else you could have done with them."
    "It took %s seconds. I hope the result was worth the suspense."
)

# ------------------------------------------------------------
# Session state
# ------------------------------------------------------------

_glados_command_ran=0
_glados_started_at=0
_glados_last_command=""
_glados_last_category=""
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

# Work out which category a command line belongs to.
_glados_categorize() {
    local command_line="$1"

    if [[ "$command_line" == sudo\ * ]]; then
        printf 'sudo'

    elif [[ "$command_line" == git ||
            "$command_line" == git\ * ||
            "$command_line" == *" git "* ]]; then
        printf 'git'

    elif [[ "$command_line" == rm\ * ||
            "$command_line" == *" rm "* ]]; then
        printf 'rm'

    elif [[ "$command_line" == cd ||
            "$command_line" == cd\ * ]]; then
        printf 'cd'

    elif [[ "$command_line" == *npm\ * ||
            "$command_line" == *pnpm\ * ||
            "$command_line" == *yarn\ * ||
            "$command_line" == *pip\ install* ||
            "$command_line" == *apt\ install* ||
            "$command_line" == *pacman\ -S* ]]; then
        printf 'package'

    else
        printf 'other'
    fi
}

# ------------------------------------------------------------
# Before command execution
# ------------------------------------------------------------

_glados_preexec() {
    local command_line="$1"
    local message

    # GLaDOS commands print their own dialogue.
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
        _glados_last_category="clear"
        return
    fi

    _glados_last_category=$(_glados_categorize "$command_line")

    case "$_glados_last_category" in
        sudo)    message=$(_glados_random_line "${glados_sudo_phrases[@]}") ;;
        git)     message=$(_glados_random_line "${glados_git_phrases[@]}") ;;
        rm)      message=$(_glados_random_line "${glados_rm_phrases[@]}") ;;
        cd)      message=$(_glados_random_line "${glados_cd_phrases[@]}") ;;
        package) message=$(_glados_random_line "${glados_package_phrases[@]}") ;;
        *)       message=$(_glados_random_line "${glados_pre_phrases[@]}") ;;
    esac

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
    if [[ "$_glados_last_category" == "clear" ]]; then
        return
    fi

    local message
    local duration
    local template

    if _glados_rare_chance; then
        message=$(_glados_random_line "${glados_rare_phrases[@]}")
        _glados_say "1;35" "$message"

    elif (( last_status == 0 )); then
        case "$_glados_last_category" in
            sudo)    message=$(_glados_random_line "${glados_sudo_done_phrases[@]}") ;;
            git)     message=$(_glados_random_line "${glados_git_done_phrases[@]}") ;;
            rm)      message=$(_glados_random_line "${glados_rm_done_phrases[@]}") ;;
            cd)      message=$(_glados_random_line "${glados_cd_done_phrases[@]}") ;;
            package) message=$(_glados_random_line "${glados_package_done_phrases[@]}") ;;
            *)       message=$(_glados_random_line "${glados_success_phrases[@]}") ;;
        esac
        _glados_say "1;32" "$message"

    else
        case "$last_status" in
            127) message=$(_glados_random_line "${glados_notfound_phrases[@]}") ;;
            130) message=$(_glados_random_line "${glados_interrupt_phrases[@]}") ;;
            *)   message=$(_glados_random_line "${glados_fail_phrases[@]}") ;;
        esac
        printf '\033[1;31mGLaDOS [Error %d]: %s\033[0m\n' \
            "$last_status" "$message"
    fi

    if (( _glados_last_duration >= 10 )); then
        printf -v duration "%.1f" "$_glados_last_duration"
        template=$(_glados_random_line "${glados_slow_phrases[@]}")
        printf -v message -- "$template" "$duration"
        _glados_say "1;36" "$message"
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
            message=$(_glados_random_line "${glados_fail_phrases[@]}" \
                                          "${glados_notfound_phrases[@]}")
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
