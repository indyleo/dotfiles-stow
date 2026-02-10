# Easier Navigation
function up() {
    local d=""
    local limit="$1"

    # Default to limit of 1
    if [[ -z "$limit" ]] || [[ "$limit" -le 0 ]]; then
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
    for f in *.*; do
        ext="${f##*.}"
        mv -f -- "$f" "${prefix}${n}.$ext"
        ((n++))
    done
    echo "Renamed ${n} files"
}

# Be Lazy With Git
function lazygall() {
    git add .
    git commit -m "$1"
    git push
}

function lazygup() {
    git add -u
    git commit -m "$1"
    git push
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
            echo "  Changed to: $dir"
        fi
    fi
}

# Screenkey
function scrky() {
    # Get screen width and calculate X position for top-right
    local screen_width=$(xrandr | grep '*' | awk '{print $1}' | cut -d 'x' -f1 | head -n1)
    local window_width=250
    local x_pos=$((screen_width - window_width - 10))

    screenkey --no-systray --opacity 0.85 \
        --bg-color "#2e3440" --font-color "#d8dee9" \
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

# For Vim Users
# vim:ft=zsh
