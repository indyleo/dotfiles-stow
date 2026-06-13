#!/usr/bin/env bash
# Dependencies: rbw, rofi (Wayland) or dmenu (X11), wl-copy or xsel/xclip

# --- Display server detection ---
if [ -n "$WAYLAND_DISPLAY" ]; then
    IS_WAYLAND=1
else
    IS_WAYLAND=0
fi

# --- Menu helper ---
MENU() {
    if [ "$IS_WAYLAND" -eq 1 ]; then
        rofi -dmenu -i -p "$1"
    else
        dmenu -p "$1"
    fi
}

# --- Error/info popup ---
POPUP() {
    if [ "$IS_WAYLAND" -eq 1 ]; then
        rofi -e "$1"
    else
        notify-send "Password" "$1"
    fi
}

# --- Clipboard helper ---
copy_to_clip() {
    if [ "$IS_WAYLAND" -eq 1 ]; then
        echo -n "$1" | wl-copy
    else
        if command -v xsel &>/dev/null; then
            echo -n "$1" | xsel --clipboard --input
        elif command -v xclip &>/dev/null; then
            echo -n "$1" | xclip -selection clipboard
        else
            echo "Error: neither xsel nor xclip found." >&2
            exit 1
        fi
    fi
}

# 1. Unlock rbw if locked
if ! rbw unlocked >/dev/null 2>&1; then
    rbw unlock
fi

# 2. Fetch entries and pipe into menu
ENTRY=$(rbw ls | sort -u | MENU "󰟵 Search:")
[ -z "$ENTRY" ] && exit 0

# 3. TOTP time remaining
REMAINING=$(( 30 - $(date +%s) % 30 ))

# 4. Action sub-menu
ACTION=$(printf "󰟵 Copy Password\n Copy Username\n󰦝 Copy TOTP (%ss left)\n󰈙 Show Details & Notes" "$REMAINING" | MENU "$ENTRY:")
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
            POPUP "$DETAILS"
        fi
        ;;
esac
