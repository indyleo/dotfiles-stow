function on_directory_change() {
    # 🌀 Git auto-pull
    if [[ -d ".git" ]] && git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "🌀 Git repo detected in $PWD, running git pull..."
        git pull --ff-only &!
        sleep 0.5
    fi

    # 🐍 Auto-activate Python virtual environment
    if [[ -f "./bin/activate" ]]; then
        echo "🐍 Activating virtual environment"
        source ./bin/activate
    fi
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd on_directory_change

# For Vim Users
# vim:ft=zsh
