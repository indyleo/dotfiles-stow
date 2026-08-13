#!/usr/bin/env sh

# Vars
XRANDR_OUTPUT="$(xrandr -q)"

# Display configuration
if echo "$XRANDR_OUTPUT" | grep -q "DP-1 connected" \
    && echo "$XRANDR_OUTPUT" | grep -q "HDMI-1-1 connected" \
    && echo "$XRANDR_OUTPUT" | grep -q "HDMI-1-4 connected"; then

    xrandr \
        --output DP-1 --mode 2560x1080 --rate 120.00 --primary \
        --output HDMI-A-1 --mode 1920x1080 --rate 74.97 --above DP-1 \
        --output HDMI-A-4 --mode 1024x600 --rate 59.82 --below DP-1 --rotate inverted

    xinput map-to-output "ILITEK       ILITEK-TOUCH" "HDMI-1-4"
    xinput set-prop "ILITEK       ILITEK-TOUCH" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1


elif echo "$XRANDR_OUTPUT" | grep -q "DP-1 connected" \
    && echo "$XRANDR_OUTPUT" | grep -q "HDMI-1-4 connected"; then

    xrandr \
        --output DP-1 --mode 2560x1080 --rate 120.00 --primary \
        --output HDMI-1-4 --mode 1024x600 --rate 59.82 --below DP-1 --rotate inverted

    xinput map-to-output "ILITEK       ILITEK-TOUCH" "HDMI-1-4"
    xinput set-prop "ILITEK       ILITEK-TOUCH" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1

elif echo "$XRANDR_OUTPUT" | grep -q "DP-1 connected" \
    && echo "$XRANDR_OUTPUT" | grep -q "HDMI-1-1 connected"; then

    xrandr \
        --output DP-1 --mode 2560x1080 --rate 120.00 --primary \
        --output HDMI-1-1 --mode 1920x1080 --rate 74.97 --above DP-1

elif echo "$XRANDR_OUTPUT" | grep -q "DP-1 connected"; then

    xrandr \
        --output DP-1 --mode 2560x1080 --rate 120.00 --primary

else

    echo "No valid display configuration found"
    echo "Defaulting to a eDP-1 configuration"
    xrandr \
        --output eDP-1 --mode 1920x1080 --rate 60.00 --primary

fi

exec dwm 2> ~/.dwm.log
