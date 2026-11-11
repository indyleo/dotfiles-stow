#!/usr/bin/env bash
# ~/.config/hypr/scripts/startup-apps.sh
#
# Launches lightweight daily-use applications.
# Heavy applications (Steam, Discord) are started manually.
# Workspace placement is handled by Hyprland Lua window rules.

set -euo pipefail

# Wait for the compositor to initialize.
sleep 2

# ========================= APPLICATIONS ============================== #

# LibreWolf → Workspace 6
if ! pgrep -x librewolf >/dev/null; then
    librewolf &
    sleep 1
fi

# Feishin → Workspace 1, touch display
if ! pgrep -x feishin >/dev/null; then
    feishin &
    sleep 1
fi

# Normal Alacritty terminal
alacritty --class Alacritty,Alacritty --title "Terminal" &

sleep 1

# btop → Workspace 8
alacritty --class btop,btop --title "btop" -e btop &

# ==================================================================== #
