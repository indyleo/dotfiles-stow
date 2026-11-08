# ------------------------------------------------------------
# Directory-change hook
#   - Git: notify only (no network, no repo changes). Use `gup` to pull.
#   - Python: detect .venv / venv / env / ./bin/activate, and only
#     deactivate environments that this hook activated itself.
# ------------------------------------------------------------
export VIRTUAL_ENV_DISABLE_PROMPT=1   # the prompt (Oh My Posh) shows the venv

typeset -g _AUTO_VENV_PROJECT=""      # project dir whose venv we auto-activated

# Explicit, fast-forward-only pull
function gup() {
    git rev-parse --is-inside-work-tree &>/dev/null || { echo "Not a git repository"; return 1; }
    git symbolic-ref -q HEAD &>/dev/null || { echo "Detached HEAD - nothing to pull"; return 1; }
    git pull --ff-only "$@"
}

# Find a venv activate script for the given directory
function _find_venv_activate() {
    local dir="$1" cand
    for cand in .venv venv env; do
        [[ -f "$dir/$cand/bin/activate" ]] && { print -r -- "$dir/$cand/bin/activate"; return 0; }
    done
    [[ -f "$dir/bin/activate" ]] && { print -r -- "$dir/bin/activate"; return 0; }
    return 1
}

function on_directory_change() {
    # --- Git: notify only -----------------------------------------------
    if git rev-parse --is-inside-work-tree &>/dev/null \
        && [[ "$(git rev-parse --show-toplevel 2>/dev/null)" == "$PWD" ]]; then
        local behind
        # Uses local refs only: no network access happens here.
        behind=$(git rev-list --count HEAD..@{u} 2>/dev/null)
        if [[ -n "$behind" ]] && (( behind > 0 )); then
            echo " Git: $behind commit(s) behind upstream (as of last fetch) - run 'gup' to pull"
        fi
    fi

    # --- Python virtual environment -------------------------------------
    local activate
    if activate=$(_find_venv_activate "$PWD"); then
        local venv_dir="${activate:h:h}"
        if [[ "$VIRTUAL_ENV" != "$venv_dir" ]]; then
            echo " Activating virtual environment (${venv_dir:t})"
            source "$activate"
            _AUTO_VENV_PROJECT="$PWD"
        fi
    elif [[ -n "$_AUTO_VENV_PROJECT" && -n "$VIRTUAL_ENV" ]] \
        && [[ "$PWD" != "$_AUTO_VENV_PROJECT" && "$PWD" != "$_AUTO_VENV_PROJECT"/* ]]; then
        # Left the project we auto-activated - deactivate
        command -v deactivate >/dev/null 2>&1 && deactivate
        _AUTO_VENV_PROJECT=""
    fi
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd on_directory_change

# For Vim Users
# vim:ft=zsh
