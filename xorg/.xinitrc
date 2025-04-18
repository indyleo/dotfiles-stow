#!/bin/env bash

# Vars
XRANDR_OUTPUT=$(xrandr -q)
PROCS=(
    clipmenud
    flameshot
    nm-applet
    dunst
    lxpolkit
    udiskie
    slstatus
)

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

StartProc() {
    for program in "${PROCS[@]}"; do
        # Check if the program is already running
        if ! pgrep -x "$program" > /dev/null; then
            # If it's not running, start it in the background
            "$program" &
        fi
    done
}

xset s off
xset s noblank
xset -dpms
dbus-update-activation-environment --systemd --all

if command_exists nvidia-settings; then
    # Configure NVIDIA settings
    nvidia-settings --assign CurrentMetaMode="nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
fi

if echo "$XRANDR_OUTPUT" | grep -q "HDMI-0 connected"; then
    xrandr \
        --output HDMI-0 --mode 1920x1080 --rate 75.00 --primary \
        --output eDP-1-1 --mode 1920x1080 --rate 120.00 --right-of HDMI-0
else
    xrandr --auto
fi

picom -b
xwalr "$HOME/Pictures/Wallpapers"
[[ -f "$HOME/.Xresources" ]] || xrdb -load "$HOME/.Xresources"
systemctl --user import-environment DISPLAY
StartProc

exec dwm
