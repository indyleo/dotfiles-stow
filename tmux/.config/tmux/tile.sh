#!/usr/bin/env bash
# tile.sh — master/stack auto-tiling for tmux.
#
# Layout:
#   +-------------+----------------+
#   |             |    stack 1     |
#   |   master    +----------------+
#   |             |    stack 2     |
#   |             +----------------+
#   |             |    stack 3     |
#   +-------------+----------------+
#
# Usage:
#   tile.sh new        create a new pane in the master/stack layout
#   tile.sh rebalance  re-apply the master/stack layout
#   tile.sh swap       swap the focused pane with master
#   tile.sh focus      toggle focus master <-> first stack pane

set -uo pipefail

# ---------- helpers ------------------------------------------------------

# tmux layout checksum: same algorithm tmux uses in layout_checksum().
layout_checksum() {
    local layout="$1"
    local csum=0 i c ord
    for ((i = 0; i < ${#layout}; i++)); do
        c="${layout:i:1}"
        ord=$(printf '%d' "'$c")
        csum=$(( ((csum >> 1) + ((csum & 1) << 15) + ord) & 0xFFFF ))
    done
    printf '%04x' "$csum"
}

# Populates PANE_IDS / PANE_LEFTS / PANE_TOPS / PANE_WIDTHS / PANE_HEIGHTS
# with the current window's panes. Ids have the leading '%' stripped.
read_panes() {
    PANE_IDS=(); PANE_LEFTS=(); PANE_TOPS=()
    PANE_WIDTHS=(); PANE_HEIGHTS=()
    local id l t w h
    while read -r id l t w h; do
        [[ -z "$id" ]] && continue
        PANE_IDS+=("${id#%}")
        PANE_LEFTS+=("$l")
        PANE_TOPS+=("$t")
        PANE_WIDTHS+=("$w")
        PANE_HEIGHTS+=("$h")
    done < <(tmux list-panes -F '#{pane_id} #{pane_left} #{pane_top} #{pane_width} #{pane_height}')
}

# Index into PANE_* arrays of the left-most pane (tie-break: top-most).
find_master_idx() {
    local n=${#PANE_IDS[@]}
    local idx=0 i
    for ((i = 1; i < n; i++)); do
        if (( PANE_LEFTS[i] < PANE_LEFTS[idx] )) || \
            (( PANE_LEFTS[i] == PANE_LEFTS[idx] && PANE_TOPS[i] < PANE_TOPS[idx] )); then
            idx=$i
        fi
    done
    echo "$idx"
}

# Emits "<checksum>,<layout>" for the given window size.
build_layout() {
    local W="$1" H="$2"
    local n=${#PANE_IDS[@]}
    (( n == 0 )) && return 1

    if (( n == 1 )); then
        local full="${W}x${H},0,0,${PANE_IDS[0]}"
        printf '%s,%s' "$(layout_checksum "$full")" "$full"
        return 0
    fi

    local m; m=$(find_master_idx)

    # Collect stack indices, sort by top (small n → simple bubble sort).
    local -a stack=()
    local i
    for ((i = 0; i < n; i++)); do
        (( i == m )) && continue
        stack+=("$i")
    done
    local ns=${#stack[@]}
    local a b tmp
    for ((a = 0; a < ns; a++)); do
        for ((b = a + 1; b < ns; b++)); do
            if (( PANE_TOPS[stack[b]] < PANE_TOPS[stack[a]] )); then
                tmp=${stack[a]}; stack[a]=${stack[b]}; stack[b]=$tmp
            fi
        done
    done

    # Master column: 50% width, full height.
    local master_w=$(( W / 2 ))
    local stack_x=$(( master_w + 1 ))
    local stack_w=$(( W - stack_x ))
    (( stack_w < 1 )) && stack_w=1

    local master_str="${master_w}x${H},0,0,${PANE_IDS[$m]}"

    # Stack column: 1/N heights. usable = H - (N-1) borders; base + remainder.
    local stack_str
    if (( ns == 1 )); then
        stack_str="${stack_w}x${H},${stack_x},0,${PANE_IDS[${stack[0]}]}"
    else
        local usable=$(( H - (ns - 1) ))
        local base=$(( usable / ns ))
        local extra=$(( usable - base * ns ))
        local y=0
        local k idx h
        local children=""
        for ((k = 0; k < ns; k++)); do
            idx=${stack[$k]}
            h=$base
            (( k < extra )) && h=$(( h + 1 ))
            (( k > 0 )) && children+=","
            children+="${stack_w}x${h},${stack_x},${y},${PANE_IDS[$idx]}"
            y=$(( y + h + 1 ))
        done
        stack_str="${stack_w}x${H},${stack_x},0[${children}]"
    fi

    local full="${W}x${H},0,0{${master_str},${stack_str}}"
    printf '%s,%s' "$(layout_checksum "$full")" "$full"
}

# ---------- commands -----------------------------------------------------

cmd_rebalance() {
    read_panes
    (( ${#PANE_IDS[@]} == 0 )) && return 0

    local sz; sz=$(tmux display-message -p '#{window_width} #{window_height}')
    local W="${sz%% *}"
    local H="${sz##* }"

    local layout
    layout=$(build_layout "$W" "$H") || return 1
    [[ -z "$layout" ]] && return 0

    tmux select-layout "$layout" >/dev/null 2>&1 || true
}

cmd_new() {
    read_panes
    local n=${#PANE_IDS[@]}
    (( n == 0 )) && return 0

    if (( n == 1 )); then
        # First tile: split the master horizontally 50/50.
        tmux split-window -h -p 50
    else
        # Split the current bottom-most stack pane vertically.
        local m; m=$(find_master_idx)
        local best_idx=-1 best_top=-1 i
        for ((i = 0; i < n; i++)); do
            (( i == m )) && continue
            if (( PANE_TOPS[i] > best_top )); then
                best_top=${PANE_TOPS[i]}
                best_idx=$i
            fi
        done
        [[ $best_idx -lt 0 ]] && return 1
        tmux select-pane -t "%${PANE_IDS[$best_idx]}"
        tmux split-window -v
    fi

    sleep 0.05
    cmd_rebalance
}

cmd_swap_master() {
    read_panes
    local n=${#PANE_IDS[@]}
    (( n < 2 )) && return 0

    local m; m=$(find_master_idx)
    local active; active=$(tmux display-message -p '#{pane_id}')
    active="${active#%}"

    # Nothing to do if the focused pane already is master.
    [[ "$active" == "${PANE_IDS[$m]}" ]] && return 0

    tmux swap-pane -s "%${PANE_IDS[$m]}" -t "%${active}" >/dev/null 2>&1 || return 1
    sleep 0.03
    cmd_rebalance
    tmux select-pane -t "%${active}" 2>/dev/null || true
}

cmd_focus_toggle() {
    read_panes
    local n=${#PANE_IDS[@]}
    (( n < 2 )) && return 0

    local m; m=$(find_master_idx)
    local active; active=$(tmux display-message -p '#{pane_id}')
    active="${active#%}"

    if [[ "$active" == "${PANE_IDS[$m]}" ]]; then
        local best_idx=-1 best_top=999999 i
        for ((i = 0; i < n; i++)); do
            (( i == m )) && continue
            if (( PANE_TOPS[i] < best_top )); then
                best_top=${PANE_TOPS[i]}
                best_idx=$i
            fi
        done
        [[ $best_idx -ge 0 ]] && tmux select-pane -t "%${PANE_IDS[$best_idx]}"
    else
        tmux select-pane -t "%${PANE_IDS[$m]}"
    fi
}

# ---------- dispatch -----------------------------------------------------

case "${1:-}" in
    new)       cmd_new ;;
    rebalance) cmd_rebalance ;;
    swap)      cmd_swap_master ;;
    focus)     cmd_focus_toggle ;;
    *)
        echo "usage: $0 {new|rebalance|swap|focus}" >&2
        exit 1
        ;;
esac
