#!/bin/env bash

# The identifier (e.g., "mail", "htop")
NAME=$1
APP_ID="termsc-$NAME"
COMMAND=${2:-zsh}

# Check if the window already exists
if hyprctl clients -j | jq -e ".[] | select(.class == \"$APP_ID\")" > /dev/null; then
    hyprctl dispatch togglespecialworkspace "$APP_ID"
else
    # 1. Launch the terminal
    foot --app-id="$APP_ID" -e "$COMMAND" &

    # 2. Wait for the window to register in Hyprland
    while ! hyprctl clients -j | jq -e ".[] | select(.class == \"$APP_ID\")" > /dev/null; do
        sleep 0.1
    done

    # 3. Apply the "Rule" settings dynamically
    # We use 'setprop' for window-specific overrides
    hyprctl dispatch setprop "class:$APP_ID" float on
    hyprctl dispatch setprop "class:$APP_ID" sizerequest 80% 80%

    # 4. Move it to its own dynamic special workspace
    hyprctl dispatch movetoworkspace "special:$APP_ID,class:$APP_ID"

    # 5. Center it (must be done after it is floating)
    hyprctl dispatch centerwindow "class:$APP_ID"

    # 6. Show it
    hyprctl dispatch togglespecialworkspace "$APP_ID"
fi
