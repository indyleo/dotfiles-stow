#!/usr/bin/env bash
# Dependencies:
#   rbw
#   Wayland + Quickshell running -> talks directly to the Quickshell Dmenu
#     picker over `qs ipc call` (no qsdmenu wrapper needed)
#   Anything else                -> dmenu
#   wl-copy (Wayland) or xsel/xclip (X11)

# --- Config ---
CLIP_TIMEOUT=30   # seconds before clipboard is cleared
IPC_TIMEOUT=60    # seconds to wait for the Quickshell picker before giving up

# --- Display server detection ---
if [ -n "$WAYLAND_DISPLAY" ]; then
    IS_WAYLAND=1
else
    IS_WAYLAND=0
fi

# --- Menu helper ---
# Wayland: talks directly to the Quickshell Dmenu picker's IPC endpoint,
# same protocol as the qsdmenu wrapper script:
#   qs ipc call pick dmenu <inputFile> <outputFifo> <prompt>
_quickshell_menu() {
    local prompt="$1"
    local tmpdir infile outfifo result

    tmpdir=$(mktemp -d) || { echo "Error: mktemp -d failed." >&2; return 1; }
    infile="$tmpdir/in"
    outfifo="$tmpdir/out"

    cat > "$infile"
    mkfifo "$outfifo"

    # Cleanup no matter how we leave this function.
    trap 'rm -rf "$tmpdir"' RETURN

    if ! timeout "$IPC_TIMEOUT" qs ipc call pick dmenu "$infile" "$outfifo" "$prompt"; then
        echo "Error: qs ipc call failed or Quickshell is not running." >&2
        return 1
    fi

    # The IPC call above blocks until the picker submits, so the fifo
    # should already have data (or be closed with none). Guard the read
    # too in case something wedges the picker after submit.
    if ! result=$(timeout "$IPC_TIMEOUT" cat "$outfifo"); then
        echo "Error: timed out waiting for picker result." >&2
        return 1
    fi

    if [ -n "$result" ]; then
        printf '%s\n' "$result"
    fi
}

MENU() {
    if [ "$IS_WAYLAND" -eq 1 ]; then
        _quickshell_menu "$1"
    else
        dmenu -p "$1"
    fi
}

# --- Error/info popup ---
# notify-send works fine on both, and the Quickshell Dmenu picker has no
# built-in message/error surface. NEVER pass secrets here — notification
# daemons commonly keep history (and can surface it on the lock screen).
POPUP() {
    notify-send "Password" "$1"
}

# --- Clipboard helpers ---
_clip_read() {
    if [ "$IS_WAYLAND" -eq 1 ]; then
        wl-paste 2>/dev/null
    elif command -v xsel &>/dev/null; then
        xsel --clipboard --output 2>/dev/null
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard -o 2>/dev/null
    fi
}

copy_to_clip() {
    local content="$1"

    if [ "$IS_WAYLAND" -eq 1 ]; then
        printf '%s' "$content" | wl-copy
    else
        if command -v xsel &>/dev/null; then
            printf '%s' "$content" | xsel --clipboard --input
        elif command -v xclip &>/dev/null; then
            printf '%s' "$content" | xclip -selection clipboard
        else
            echo "Error: neither xsel nor xclip found." >&2
            exit 1
        fi
    fi

    # Auto-clear after CLIP_TIMEOUT, but only if the clipboard still
    # holds exactly what we put there (don't clobber something the user
    # copied afterwards). Detached so the script can exit immediately.
    (
        sleep "$CLIP_TIMEOUT"
        current=$(_clip_read)
        if [ "$current" = "$content" ]; then
            if [ "$IS_WAYLAND" -eq 1 ]; then
                printf '' | wl-copy
            elif command -v xsel &>/dev/null; then
                printf '' | xsel --clipboard --input
            elif command -v xclip &>/dev/null; then
                printf '' | xclip -selection clipboard
            fi
        fi
    ) & disown
}

# 1. Unlock rbw if locked
if ! rbw unlocked >/dev/null 2>&1; then
    rbw unlock
fi

# 2. Fetch entries and pipe into menu
ENTRIES=$(rbw ls) || { POPUP "rbw ls failed — is rbw unlocked and reachable?"; exit 1; }
ENTRY=$(printf '%s\n' "$ENTRIES" | sort -u | MENU "󰟵 Search:")
[ -z "$ENTRY" ] && exit 0

# 3. TOTP time remaining
REMAINING=$(( 30 - $(date +%s) % 30 ))

# 4. Action sub-menu
ACTION=$(printf "󰟵 Copy Password\n Copy Username\n󰦝 Copy TOTP (%ss left)\n󰈙 Show Details & Notes" "$REMAINING" | MENU "$ENTRY:")
[ -z "$ACTION" ] && exit 0

# 5. Handle action
case "$ACTION" in
    *"Copy Password")
        PASS=$(rbw get "$ENTRY")
        copy_to_clip "$PASS"
        ;;

    *"Copy Username")
        USER=$(rbw get --full "$ENTRY" | grep -i '^Username:' | sed 's/^Username://' | sed 's/^[ \t]*//')
        if [ -z "$USER" ]; then
            POPUP "No username found for this entry."
        else
            copy_to_clip "$USER"
        fi
        ;;

    *"Copy TOTP"*)
        TOTP=$(rbw code "$ENTRY" 2>/dev/null)
        if [ -z "$TOTP" ]; then
            POPUP "No TOTP configured for this entry."
        else
            copy_to_clip "$TOTP"
        fi
        ;;

    *"Show Details & Notes")
        DETAILS=$(rbw get --full "$ENTRY" | tail -n +2)
        if [ -z "$DETAILS" ]; then
            POPUP "No additional notes or metadata found."
        else
            # Route through the picker itself instead of notify-send:
            # details may include secrets, and notification daemons often
            # keep history / surface on the lock screen. The picker just
            # displays a list to browse; Esc/Cancel discards it, nothing
            # is written anywhere.
            printf '%s\n' "$DETAILS" | MENU "$ENTRY details (Esc to close):" >/dev/null
        fi
        ;;
esac
