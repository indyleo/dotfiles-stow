#!/usr/bin/env bash

# Dependencies: rofi, rbw, a clipboard manager (xclip or wl-copy)

# --- Configuration ---
# Choose your clipboard tool depending on X11 vs Wayland
CLIPBOARD_CMD="wl-copy" # or "xclip -selection clipboard"
ROFI_ARGS="-i" # -i makes search case-insensitive
# ---------------------

# Helper function to copy to clipboard
copy_to_clip() {
    echo -n "$1" | eval "$CLIPBOARD_CMD"
}

# 1. Unlock rbw if it is currently locked (triggers your default pinentry)
if ! rbw unlocked >/dev/null 2>&1; then
    rbw unlock
fi

# 2. Fetch entries and pipe them into rofi
ENTRY=$(rbw ls | sort -u | rofi -dmenu -p "󰟵 Search:" $ROFI_ARGS)

# Exit if the user presses Escape
[ -z "$ENTRY" ] && exit 0

# 3. Calculate TOTP time remaining (30-second window)
# This calculates how many seconds are left until the next 30-second rollover
REMAINING=$(( 30 - $(date +%s) % 30 ))

# 4. Create the sub-menu for the selected entry
# The %ss adds the calculated seconds to the menu item
ACTION=$(printf "󰟵 Copy Password\n Copy Username\n󰦝 Copy TOTP (%ss left)\n󰈙 Show Details & Notes" "$REMAINING" | rofi -dmenu -p "$ENTRY:" $ROFI_ARGS)

[ -z "$ACTION" ] && exit 0

# 5. Handle the chosen action
case "$ACTION" in
    *"Copy Password")
        PASS=$(rbw get "$ENTRY")
        copy_to_clip "$PASS"
        ;;

    *"Copy Username")
        # 'rbw get --full' outputs metadata. We grep for the username line, strip the label, and strip leading spaces.
        USER=$(rbw get --full "$ENTRY" | grep -i '^Username:' | sed 's/^Username://' | sed 's/^[ \t]*//')
        if [ -z "$USER" ]; then
            rofi -e "No username found for this entry."
        else
            copy_to_clip "$USER"
        fi
        ;;

    *"Copy TOTP"*)
        # Match using wildcards because the string contains the dynamic "(#s left)" text
        TOTP=$(rbw code "$ENTRY" 2>/dev/null)
        if [ -z "$TOTP" ]; then
            rofi -e "No TOTP configured for this entry."
        else
            copy_to_clip "$TOTP"
        fi
        ;;

    *"Show Details & Notes")
        # 'tail -n +2' removes the 1st line (plaintext password) for security
        DETAILS=$(rbw get --full "$ENTRY" | tail -n +2)

        if [ -z "$DETAILS" ]; then
            rofi -e "No additional notes or metadata found."
        else
            rofi -e "$DETAILS"
        fi
        ;;
esac
