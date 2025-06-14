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
fi

# Archive Extraction
function extract() {
    if [[ "$#" -lt 1 ]]; then
        echo "Usage: extract <archive_file>"
        return 1
    fi

    if [[ -f "$1" ]]; then
        case $1 in
            *.tar.bz2) tar xjf "$1"    ;;
            *.tar.gz)  tar xzf "$1"    ;;
            *.bz2)     bunzip2 "$1"    ;;
            *.rar)     unrar x "$1"    ;;
            *.gz)      gunzip "$1"     ;;
            *.tar)     tar xf "$1"     ;;
            *.tbz2)    tar xjf "$1"    ;;
            *.tgz)     tar xzf "$1"    ;;
            *.zip)     unzip "$1"      ;;
            *.Z)       uncompress "$1" ;;
            *.7z)      7z x "$1"       ;;
            *.deb)     ar x "$1"       ;;
            *.tar.xz)  tar xf "$1"     ;;
            *.tar.zst) unzstd "$1"     ;;
            *)         echo "'$1' cannot be extracted via extract" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Archiving
function archive() {
    if [[ "$#" -lt 2 ]]; then
        echo "Usage: archive <archive_name.tar.gz|archive_name.zip|archive_name.rar> <file1> [file2 ... fileN]"
        return 1
    fi

    archive_name="$1"
    shift

    if [[ -e "$archive_name" ]]; then
        echo "Error: Archive '$archive_name' already exists."
        return 1
    fi

    case "$archive_name" in
        *.tar.gz)
            tar -czf "$archive_name" "$@"
            ;;
        *.zip)
            zip -r "$archive_name" "$@"
            ;;
        *.rar)
            if command -v rar > /dev/null; then
                rar a "$archive_name" "$@"
            else
                echo "Error: 'rar' command not found. Please install RAR to create .rar archives."
                return 1
            fi
            ;;
        *)
            echo "Error: Unsupported archive format. Supported formats are .tar.gz, .zip, and .rar."
            return 1
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        echo "Success: Archive created: $archive_name"
    else
        echo "Error: Failed to create archive."
        return 1
    fi
}

function massrename() {
    for f in *.*; do
        ext="${f##*.}"
        mv -f -- "$f" "wall${n}.$ext"
        ((n++))
    done
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
    local theme
    theme="$(cat ${XDG_CACHE_HOME:-$HOME/.cache}/theme)"
    if [[ "$theme" == "nord" ]]; then
        screenkey --no-systray --opacity 0.85 \
            --bg-color "#3b4252" --font-color "#d8dee9" \
            -p fixed -g 627x40+1283+35 &
    elif [[ "$theme" == "gruvbox" ]]; then
        screenkey --no-systray --opacity 0.85 \
            --bg-color "#282828" --font-color "#ebdbb2" \
            -p fixed -g 627x40+1283+35 &
    fi

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
    files=$(find . -maxdepth 5 -type f | fzf -m --preview='batcat --color=always --style=numbers {}')
    [[ -z "$files" ]] && return

    # Turn newline-separated string into array safely
    local -a file_array
    file_array=("${(f)files}")

    nvim "${file_array[@]}"
}

# For Vim Users
# vim:ft=zsh
