#!/bin/env bash

# Usage: ./scratchpad.sh <name> <command> [--gui]
# Example TUI: ./scratchpad.sh htop htop
# Example GUI: ./scratchpad.sh feishin feishin --gui

NAME=$1
COMMAND=$2
ARGS=$@

# 1. Determine mode (GUI vs TUI)
if [[ "$ARGS" == *"--gui"* ]]; then
    # GUI Mode:
    # Use the NAME directly as the Class ID (Case Sensitive!)
    # We do NOT prepend "termsc-" because we can't easily force class names on all GUI apps.
    APP_ID="$NAME"
    LAUNCH_CMD="$COMMAND"
else
    # TUI Mode (Default):
    # Prepend identifier to ensure this specific terminal instance is unique
    APP_ID="termsc-$NAME"
    # Wrap in foot
    LAUNCH_CMD="foot --app-id=$APP_ID -e $COMMAND"
fi

# Check if the window already exists
if hyprctl clients -j | jq -e ".[] | select(.class == \"$APP_ID\")" > /dev/null; then
    hyprctl dispatch togglespecialworkspace "$APP_ID"
else
    # 1. Launch the app
    # We run it in the background
    $LAUNCH_CMD &

    # 2. Wait for the window to register in Hyprland
    # Increased timeout slightly for heavier GUI apps (Electron apps like Feishin take time)
    MAX_RETRIES=50
    COUNT=0
    while ! hyprctl clients -j | jq -e ".[] | select(.class == \"$APP_ID\")" > /dev/null; do
        if [ $COUNT -ge $MAX_RETRIES ]; then
            notify-send "Scratchpad Error" "Could not find window class: $APP_ID"
            exit 1
        fi
        sleep 0.1
        ((COUNT++))
    done

    # 3. Apply the "Rule" settings dynamically
    # 'setprop' is great for this because it targets the specific window class
    hyprctl dispatch setprop "class:$APP_ID" float on
    hyprctl dispatch setprop "class:$APP_ID" sizerequest 80% 80%

    # 4. Move it to its own dynamic special workspace
    hyprctl dispatch movetoworkspace "special:$APP_ID,class:$APP_ID"

    # 5. Center it
    hyprctl dispatch centerwindow "class:$APP_ID"

    # 6. Show it
    hyprctl dispatch togglespecialworkspace "$APP_ID"
fi
