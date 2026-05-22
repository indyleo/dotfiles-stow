#!/bin/env bash
# Usage: ./scratchpad.sh <name> <command> [--gui]
# Example TUI: ./scratchpad.sh htop htop
# Example GUI: ./scratchpad.sh feishin feishin --gui

NAME=$1
COMMAND=$2

# 1. Determine mode (GUI vs TUI)
if [[ "$*" == *"--gui"* ]]; then
    APP_ID="$NAME"
    LAUNCH_CMD="$COMMAND"
else
    APP_ID="termsc-$NAME"
    LAUNCH_CMD="footclient --app-id $APP_ID $COMMAND"
fi

# hyprctl dispatch in 0.55+ parses args as Lua — use hl.dsp.* syntax
toggle_scratch() {
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"${APP_ID}\")"
}

# 2. If window already exists, just toggle its special workspace
if hyprctl clients -j | jq -e ".[] | select(.class == \"$APP_ID\")" > /dev/null 2>&1; then
    toggle_scratch
    exit 0
fi

# 3. Pre-register window rules before launch (Hyprland 0.55+ Lua API)
# size takes {w, h} as integers or monitor-relative expressions
hyprctl eval "hl.window_rule({ match = { class = \"^(${APP_ID})$\" }, float = true })"
hyprctl eval "hl.window_rule({ match = { class = \"^(${APP_ID})$\" }, size = { \"(monitor_w*0.9)\", \"(monitor_h*0.9)\" } })"
hyprctl eval "hl.window_rule({ match = { class = \"^(${APP_ID})$\" }, center = true })"
hyprctl eval "hl.window_rule({ match = { class = \"^(${APP_ID})$\" }, workspace = \"special:${APP_ID} silent\" })"

# 4. Launch the app
$LAUNCH_CMD &

# 5. Wait for the window to appear
MAX_RETRIES=50
COUNT=0
while ! hyprctl clients -j | jq -e ".[] | select(.class == \"$APP_ID\")" > /dev/null 2>&1; do
    if [ $COUNT -ge $MAX_RETRIES ]; then
        notify-send "Scratchpad Error" "Could not find window class: $APP_ID"
        exit 1
    fi
    sleep 0.1
    ((COUNT++))
done

# 6. Show it
toggle_scratch
