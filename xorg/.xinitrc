#!/bin/env sh

# Get window manager choice and username
WNC="$1"
ACC="$(whoami)"

# Start necessary services
udiskie &

# Configure NVIDIA settings
nvidia-settings --assign CurrentMetaMode="nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"

# Check for HDMI connection and configure display settings accordingly
if xrandr -q | grep -q 'HDMI-0 connected'; then
    xrandr --output HDMI-0 --mode 1920x1080 --rate 75.00 --primary \
        --output eDP-1-1 --right-of HDMI-0 --mode 1920x1080 --rate 120.00
else
    xrandr --auto
fi

# Start WM of choice
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
