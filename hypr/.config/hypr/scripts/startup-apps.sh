#!/usr/bin/env bash
# ~/.config/hypr/scripts/startup-apps.sh
#
# Launches all daily apps. Workspace placement is handled by the window
# rules in rules.lua (matched by class), so this script only starts the
# processes and skips any that are already running.
#
# hyprsplit layout (num_workspaces = 5):
#   monitor 0  HDMI-A-1  (top)    -> workspaces  1-5
#   monitor 1  DP-1      (main)   -> workspaces  6-10
#   monitor 2  HDMI-A-4  (touch)  -> workspaces 11-15

set -uo pipefail

# ========================= HELPERS =================================== #

# Wait for the compositor to be ready.
for _ in $(seq 1 20); do
    hyprctl monitors >/dev/null 2>&1 && break
    sleep 0.5
done

# is_running CLASS [TITLE]
is_running() {
    local class="$1" title="${2:-}"
    hyprctl clients -j | jq -e --arg c "$class" --arg t "$title" \
        'any(.[]; .class == $c and ($t == "" or .title == $t))' >/dev/null
}

# launch CLASS TITLE COMMAND...
# TITLE may be "" to ignore the title when checking if already running.
launch() {
    local class="$1" title="$2"
    shift 2
    if is_running "$class" "$title"; then
        return
    fi
    setsid -f "$@" >/dev/null 2>&1
    sleep 1
}

# ========================= LAUNCH ==================================== #

launch librewolf ""         librewolf
launch feishin   ""         feishin
launch Alacritty "Terminal" alacritty --class Alacritty,Alacritty --title Terminal
launch btop      ""         alacritty --class btop,btop --title btop -e btop
launch vesktop   ""         vesktop
launch steam     ""         steam
