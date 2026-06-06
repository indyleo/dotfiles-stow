#!/usr/bin/env bash

# Vars
XRANDR_OUTPUT=$(xrandr -q)
PROCS=(
    dunst
    lxpolkit
    udiskie
    medianotify
    dwmblocks
    sxhkd
)
DAEMON_PROCS=(
    "clipmgr.py daemon"
    "organizer.py --daemon"
    "desktopctl time ~/Pictures/Wallpapers/gruvbox 900"
    "python3 -m http.server 8080 --bind 127.0.0.1 --directory ~/.config/startpage"
)

# Functions
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Conditional additions
if command_exists sunshine; then
    PROCS+=("sunshine")
fi
if command_exists solaar; then
    DAEMON_PROCS+=("solaar --window hide")
fi

start_processes() {
    for program in "${PROCS[@]}"; do
        if ! pidof -x "$program" > /dev/null 2>&1; then
            "$program" &
            sleep 0.1
        fi
    done
}

start_daemons() {
    for cmd in "${DAEMON_PROCS[@]}"; do
        program=$(echo "$cmd" | awk '{print $1}')
        if ! pgrep -f "$program" > /dev/null; then
            $cmd &
            sleep 0.1
        fi
    done
}

# Main execution
xset s off -dpms
xset s noblank
xsetroot -cursor_name left_ptr
dbus-update-activation-environment --systemd --all

# NVIDIA settings
if command_exists nvidia-settings; then
    nvidia-settings --assign CurrentMetaMode="nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
fi

# Display configuration
if echo "$XRANDR_OUTPUT" | grep -q "DP-1 connected" \
    && echo "$XRANDR_OUTPUT" | grep -q "HDMI-A-1 connected" \
    && echo "$XRANDR_OUTPUT" | grep -q "HDMI-A-4 connected"; then

    xrandr \
        --output DP-1 --mode 2560x1080 --rate 120.00 --primary \
        --output HDMI-A-1 --mode 1920x1080 --rate 74.97 --above DP-1 \
        --output HDMI-A-4 --mode 1024x600 --rate 59.82 --below DP-1 --rotate inverted

elif echo "$XRANDR_OUTPUT" | grep -q "DP-1 connected"; then

    xrandr \
        --output DP-1 --mode 2560x1080 --rate 120.00 --primary

fi

# Start compositor
picom -b

# Load X resources
[[ -f "$HOME/.Xresources" ]] && xrdb -load "$HOME/.Xresources"

# Import environment
systemctl --user import-environment DISPLAY

# Start all processes
start_processes
start_daemons

exec dwm
