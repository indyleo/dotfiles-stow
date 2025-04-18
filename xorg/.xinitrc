#!/bin/env bash

# Vars
WNC="$1"
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
        pgrep -x "$program" > /dev/null || "$program" &
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

# Check for HDMI connection and configure display settings accordingly
if xrandr -q | grep -q "Virtual-1 connected"; then
    xrandr --output "Virtual-1" --mode "1920x1080" # For Vm's
elif xrandr -q | grep -q 'HDMI-0 connected'; then
    xrandr --output HDMI-0 --mode 1920x1080 --rate 75.00 --primary \
        --output eDP-1-1 --right-of HDMI-0 --mode 1920x1080 --rate 120.00
else
    xrandr --auto
fi

picom -b
xwalr "$HOME/Pictures/Wallpapers"
[[ -f "$HOME/.Xresources" ]] || xrdb -load "$HOME/.Xresources"
systemctl --user import-environment DISPLAY
StartProc

# Launch the selected window manager
case "$WNC" in
    dwm) exec dwm ;;
    awesome) exec awesome ;;
    bspwm) exec bspwm ;;
    xmonad) exec xmonad-session ;;
    *)
        echo "Invalid window manager: $WNC. Defaulting to dwm."
        exec dwm
        ;;
esac
