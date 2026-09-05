function on_directory_change() {
    #  Git auto-pull (skip if mid-rebase/detached HEAD - no branch to ff-pull)
    if [[ -d ".git" ]] && git rev-parse --is-inside-work-tree &>/dev/null; then
        if git symbolic-ref -q HEAD &>/dev/null; then
            echo " Git repo detected in $PWD, running git pull..."
            git pull --ff-only &>/dev/null &!
        fi
    fi

    # 🐍 Auto-activate Python virtual environment
    if [[ -f "./bin/activate" ]]; then
        if [[ "$VIRTUAL_ENV" != "$PWD" ]]; then
            echo "🐍 Activating virtual environment"
            source ./bin/activate
        fi
    elif [[ -n "$VIRTUAL_ENV" ]] && [[ "$PWD" != "$VIRTUAL_ENV"/* ]]; then
        # Left the venv's directory tree - deactivate automatically
        command -v deactivate >/dev/null 2>&1 && deactivate
    fi
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd on_directory_change

# For Vim Users
# vim:ft=zsh
