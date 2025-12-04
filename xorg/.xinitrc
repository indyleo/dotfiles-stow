#!/usr/bin/env bash

# Vars
XRANDR_OUTPUT=$(xrandr -q)
PROCS=(
    dunst
    lxpolkit
    udiskie
    medianotify
    dwmblocks
)
DAEMON_PROCS=(
    "clipmgr.py daemon"
    "organizer.py --daemon"
)
ONESHOT_CMDS=(
    "desktopctl wallpaper theme-time"
    "xss-lock slock"
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

run_oneshot() {
    for cmd in "${ONESHOT_CMDS[@]}"; do
        $cmd &
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
if echo "$XRANDR_OUTPUT" | grep -q "HDMI-0 connected"; then
    xrandr \
        --output HDMI-0 --mode 1920x1080 --rate 75.00 --primary \
        --output eDP-1-1 --mode 1920x1080 --rate 120.00 --right-of HDMI-0
elif echo "$XRANDR_OUTPUT" | grep -q "HDMI-1 connected" && echo "$XRANDR_OUTPUT" | grep -q "eDP-1 connected"; then
    xrandr \
        --output eDP-1 --mode 1366x768 --rate 60.00 --primary \
        --output HDMI-1 --mode 1024x600 --rate 60.00 --right-of eDP-1
elif echo "$XRANDR_OUTPUT" | grep -q "eDP-1 connected"; then
    xrandr --output eDP-1 --mode 1366x768 --rate 60.00 --primary
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
run_oneshot

exec dwm
