#!/usr/bin/env bash
# ~/.config/hypr/scripts/startup-apps.sh
#
# Launches all daily apps and puts them on the right workspace.
#
# hyprsplit layout (num_workspaces = 5), monitor order from `hyprctl clients`:
#   monitor 0  HDMI-A-1  (top)    → workspaces  1-5
#   monitor 1  DP-1      (main)   → workspaces  6-10
#   monitor 2  HDMI-A-4  (touch)  → workspaces 11-15
#
# Placement uses the global workspace IDs, which is what Hyprland actually
# sees under hyprsplit. Each app is launched with an exec rule, then a
# verification pass moves anything that landed somewhere else (e.g. because
# a window rule in rules.lua disagreed).

set -uo pipefail

# ========================= WORKSPACE MAP ============================= #

WS_BTOP=1        # top monitor
WS_LIBREWOLF=6   # main monitor
WS_VESKTOP=7     # main monitor
WS_TERMINAL=8    # main monitor
WS_STEAM=9       # main monitor
WS_FEISHIN=11    # touch monitor (its first workspace)

# ========================= HELPERS =================================== #

# Wait for the compositor to be ready.
for _ in $(seq 1 20); do
    hyprctl monitors >/dev/null 2>&1 && break
    sleep 0.5
done

# is_running CLASS [TITLE]
function is_running() {
    local class="$1" title="${2:-}"
    hyprctl clients -j | jq -e --arg c "$class" --arg t "$title" \
        'any(.[]; .class == $c and ($t == "" or .title == $t))' >/dev/null
}

# launch WORKSPACE CLASS TITLE COMMAND...
# TITLE may be "" to ignore title when checking if already running.
function launch() {
    local ws="$1" class="$2" title="$3"
    shift 3
    if is_running "$class" "$title"; then
        return
    fi
    hyprctl dispatch exec "[workspace $ws silent] $*" >/dev/null
    sleep 1
}

# verify WORKSPACE CLASS
# Waits for the window, then moves it if it's on the wrong workspace.
function verify() {
    local ws="$1" class="$2" current
    for _ in $(seq 1 30); do
        current=$(hyprctl clients -j | jq -r --arg c "$class" \
            '[.[] | select(.class == $c)][0].workspace.id // empty')
        if [[ -n "$current" ]]; then
            if [[ "$current" != "$ws" ]]; then
                hyprctl dispatch movetoworkspacesilent "$ws,class:^${class}$" >/dev/null
            fi
            return
        fi
        sleep 0.5
    done
    echo "startup-apps: $class never appeared" >&2
}

# ========================= LAUNCH ==================================== #

launch "$WS_LIBREWOLF" librewolf "" librewolf
launch "$WS_FEISHIN"   feishin   "" feishin
launch "$WS_TERMINAL"  Alacritty "Terminal" \
    alacritty --class Alacritty,Alacritty --title Terminal
launch "$WS_BTOP"      btop      "" \
    alacritty --class btop,btop --title btop -e btop
launch "$WS_VESKTOP"   vesktop   "" vesktop
launch "$WS_STEAM"     steam     "" steam

# ========================= VERIFY ==================================== #

verify "$WS_LIBREWOLF" librewolf
verify "$WS_FEISHIN"   feishin
verify "$WS_TERMINAL"  Alacritty
verify "$WS_BTOP"      btop
verify "$WS_VESKTOP"   vesktop
verify "$WS_STEAM"     steam
