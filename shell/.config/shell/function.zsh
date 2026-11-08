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

# Bat Cat
function cat() {
    if [[ -n "$WIDGET" ]]; then
        command cat "$@"
    else
        command bat -pn --pager="" "$@"
    fi
}

# For Vim Users
# vim:ft=zsh
