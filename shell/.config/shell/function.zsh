# Easier Navigation
function up() {
    local d=""
    local limit="$1"

    # Default to limit of 1 if empty, non-numeric, or <= 0
    if [[ -z "$limit" ]] || [[ ! "$limit" =~ ^[0-9]+$ ]] || (( limit <= 0 )); then
        limit=1
    fi

    for ((i=1;i<=limit;i++)); do
        d="../$d"
    done

    # perform cd. Show error if cd fails
    if ! cd "$d"; then
        echo "Couldn't go up $limit dirs.";
    fi
}

# if command exits
function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Copy and go to the directory
function cpg() {
    if [[ -d "$2" ]]; then
        cp "$1" "$2" && cd "$2"
    else
        cp "$1" "$2"
    fi
}

# Move and go to the directory
function mvg() {
    if [[ -d "$2" ]]; then
        mv "$1" "$2" && cd "$2"
    else
        mv "$1" "$2"
    fi
}

# Create and go to the directory
function mkcd() {
    mkdir -p "$1"
    cd "$1"
}

# Pacman Manager
if command_exists pacman; then
    function pac() {
        if [[ -z "$1" ]]; then
            command pacman -h
            return
        fi

        case "$1" in
            -S|-Sy|-Syu|-R|-Rns|-U|-D|--clean)
                command sudo pacman "$@"
                ;;
            *)
                command pacman "$@"
                ;;
        esac
    }
elif command_exists apt; then
    function apt() {
        if [[ -z "$1" ]]; then
            command apt --help
            return
        fi

        case "$1" in
            install|update|upgrade|full-upgrade|dist-upgrade|remove|purge|autoremove|clean|autoclean)
                command sudo apt "$@"
                ;;
            *)
                command apt "$@"
                ;;
        esac
    }
elif command_exists dnf; then
    function dnf() {
        if [[ -z "$1" ]]; then
            command dnf --help
            return
        fi

        case "$1" in
            install|update|upgrade|remove)
                command sudo dnf "$@"
                ;;
            *)
                command dnf "$@"
                ;;
        esac
    }
fi

function massrename() {
    local prefix="${1:-file}"
    local ext
    local n=1
    for f in *.*; do
        [[ -f "$f" ]] || continue
        ext="${f##*.}"
        # -n (no-clobber) so we never silently overwrite a colliding name
        if mv -n -- "$f" "${prefix}${n}.$ext"; then
            ((n++))
        fi
    done
    echo "Renamed $((n - 1)) files"
}

# Be Lazy With Git (with checks and confirmation)
# Usage: lazygall "message"   -> git add -A, commit, push
#        lazygup  "message"   -> git add -u (tracked files only), commit, push
function _lazy_git() {
    local mode="$1" msg="$2" branch
    [[ -z "$msg" ]] && { echo "Usage: lazyg${mode} \"commit message\""; return 1; }
    git rev-parse --is-inside-work-tree &>/dev/null || { echo "Not a git repository"; return 1; }
    branch=$(git symbolic-ref --short -q HEAD) || { echo "Detached HEAD - refusing to commit"; return 1; }

    if [[ "$mode" == "all" ]]; then git add -A; else git add -u; fi

    if git diff --cached --quiet; then
        echo "Nothing staged - nothing to commit"
        return 0
    fi

    echo "Branch: $branch"
    git diff --cached --stat

    # Warn about files that commonly contain secrets
    local risky
    risky=$(git diff --cached --name-only | grep -Ei '(^|/)(\.env[^/]*|id_(rsa|ed25519)|.*\.(pem|key|p12|pfx))$')
    if [[ -n "$risky" ]]; then
        echo "\nPossible secrets staged:\n$risky"
        read -q "?Continue anyway? [y/N] " || { echo; git reset -q; echo "Aborted (changes unstaged)"; return 1; }
        echo
    fi

    read -q "?Commit to '$branch'? [y/N] " || { echo; git reset -q; echo "Aborted (changes unstaged)"; return 1; }
    echo
    git commit -m "$msg" || return 1

    read -q "?Push '$branch' now? [y/N] " || { echo; echo "Committed, not pushed"; return 0; }
    echo
    git push
}
function lazygall() { _lazy_git all "$1"; }
function lazygup()  { _lazy_git up  "$1"; }

# Explicit permission helpers (replacing the old recursive 644/666/755/777 aliases)
# setperm [-R] MODE PATH...
function setperm() {
    local recursive=0
    [[ "$1" == "-R" ]] && { recursive=1; shift; }
    local mode="$1"; shift
    if [[ -z "$mode" || $# -eq 0 ]]; then
        echo "Usage: setperm [-R] MODE PATH..."; return 1
    fi
    local p real
    for p in "$@"; do
        real="${p:A}"
        if [[ "$real" == "/" || "$real" == "$HOME" ]]; then
            echo "Refusing to change permissions on $real"; return 1
        fi
    done
    if (( recursive )) || [[ "$mode" == 666 || "$mode" == 777 ]]; then
        echo "About to run: chmod $( (( recursive )) && echo -R ) $mode $*"
        read -q "?Continue? [y/N] " || { echo; return 1; }
        echo
    fi
    if (( recursive )); then command chmod -R -v "$mode" -- "$@"; else command chmod -v "$mode" -- "$@"; fi
}

# fixperms [DIR]: directories 755, files 644 (preview first)
function fixperms() {
    local dir="${1:-.}"
    echo "Will set directories to 755 and files to 644 under: ${dir:A}"
    echo "Files that would change:"
    find "$dir" -type d ! -perm 755 -print 2>/dev/null | head -20
    find "$dir" -type f ! -perm 644 -print 2>/dev/null | head -20
    read -q "?Apply? [y/N] " || { echo; return 1; }
    echo
    find "$dir" -type d -exec chmod 755 {} +
    find "$dir" -type f -exec chmod 644 {} +
}

# Everyday helpers
function take() { mkcd "$@"; }

function mktempdir() {
    local d
    d=$(mktemp -d "${TMPDIR:-/tmp}/tmp.XXXXXX") && cd "$d" && echo "In $d"
}

function backup() {
    [[ -z "$1" ]] && { echo "Usage: backup FILE_OR_DIR"; return 1; }
    command cp -a -- "$1" "${1%/}.bak.$(date +%Y%m%d-%H%M%S)"
}

function extract() {
    [[ -f "$1" ]] || { echo "Usage: extract ARCHIVE"; return 1; }
    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.gz|*.tgz)   tar xzf "$1" ;;
        *.tar.xz|*.txz)   tar xJf "$1" ;;
        *.tar.zst)        tar --zstd -xf "$1" ;;
        *.tar)            tar xf "$1" ;;
        *.zip)            unzip "$1" ;;
        *.7z)             7z x "$1" ;;
        *.rar)            unrar x "$1" ;;
        *.gz)             gunzip "$1" ;;
        *.bz2)            bunzip2 "$1" ;;
        *.xz)             unxz "$1" ;;
        *) echo "extract: unknown archive type '$1'"; return 1 ;;
    esac
}

# Interactive process killer (fzf)
function fkill() {
    local pid
    pid=$(ps -u "$USER" -o pid,pcpu,pmem,comm --sort=-pcpu | sed 1d | fzf -m --header='TAB: multi-select, ENTER: kill' | awk '{print $1}')
    [[ -z "$pid" ]] && return
    echo "$pid" | xargs kill "${1:--15}"
}

# Project root: git toplevel, else the nearest directory with a known marker.
# Same markers as the Neovim sessions/test-runner plugins.
function proot() {
    local d="$PWD" m top
    top=$(git rev-parse --show-toplevel 2>/dev/null) && { print -r -- "$top"; return 0; }
    while [[ "$d" != "/" ]]; do
        for m in Cargo.toml go.mod pyproject.toml package.json CMakeLists.txt Makefile; do
            [[ -e "$d/$m" ]] && { print -r -- "$d"; return 0; }
        done
        d="${d:h}"
    done
    return 1
}

# cd to the project root
function pcd() {
    local r
    r=$(proot) || { echo "No project root found"; return 1; }
    cd "$r"
}

# Open a new Alacritty window at a project root, restoring its Neovim session.
#   tproj [dir]   (defaults to the current project root, else $PWD)
function tproj() {
    local dir="${1:-$(proot 2>/dev/null)}"
    dir="${dir:-$PWD}"
    [[ -d "$dir" ]] || { echo "tproj: no such directory: $dir"; return 1; }
    command -v alacritty >/dev/null 2>&1 || { echo "tproj: alacritty not found"; return 1; }
    alacritty --working-directory "$dir" -e zsh -c 'nvim -c "silent! SessionLoad"; exec zsh' &>/dev/null &!
}

# New fully opaque Alacritty window (e.g. for screen sharing)
function term-opaque() {
    alacritty -o window.opacity=1.0 &>/dev/null &!
}

# Lf CD
function lc() {
    # Create a temporary file to store the last directory
    local tmp dir
    tmp="$(mktemp "${TMPDIR:-/tmp}/lc-cwd.XXXXXX")" || return

    # Launch lf and store the last directory in tmp
    command lf -last-dir-path="$tmp" "$@" || return

    # Read and validate the result
    if [[ -f $tmp ]]; then
        dir=$(<"$tmp")
        command rm -f -- "$tmp"
        if [[ -d $dir && $dir != "$PWD" ]]; then
            cd "$dir" || return
            echo "󰉋 Changed to: $dir"
        fi
    fi
}

# Lf Pick
function lp() {
    local tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/lf-pick.XXXXXX")" || return
    command lf -selection-path "$tmp" </dev/tty
    local -a picked
    [[ -s $tmp ]] && picked=("${(@f)$(<"$tmp")}")
    command rm -f -- "$tmp"
    (( ${#picked} )) && LBUFFER+="${LBUFFER:+ }${(j: :)${(@q)picked}}"
    zle reset-prompt
}
zle -N lp

# Screenkey
function scrky() {
    # Get screen width and calculate X position for top-right
    local screen_width=$(xrandr | grep '*' | awk '{print $1}' | cut -d 'x' -f1 | head -n1)
    local window_width=250
    local x_pos=$((screen_width - window_width - 10))

    screenkey --no-systray --opacity 0.85 \
        --bg-color "#282828" --font-color "#d5c4a1" \
        -p fixed -g ${window_width}x40+${x_pos}+10 &
    SCREENKEY_PID=$!
    if [[ -n $ZSH_VERSION ]]; then
        echo "Press enter to close screenkey"
        read
    else
        read -p "Press enter to close screenkey"
    fi
    kill "$SCREENKEY_PID" 2>/dev/null
}

function edit() {
    local files
    files=$(find . -maxdepth 5 -type f | fzf -m --preview='bat --color=always --style=numbers {}')
    [[ -z "$files" ]] && return

    # Turn newline-separated string into array safely
    local -a file_array
    file_array=("${(f)files}")

    nvim "${file_array[@]}"
}

# Bat Cat
cat() {
    if [[ -n "$WIDGET" ]]; then
        command cat "$@"
    else
        command bat -pn --pager="" "$@"
    fi
}

# For Vim Users
# vim:ft=zsh
