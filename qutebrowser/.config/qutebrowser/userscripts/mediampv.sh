#!/bin/env bash
# This script sends the current URL to mpv
# Requires: mpv and yt-dlp

[[ -z "$QUTE_URL" ]] && exit 1

ARG="$1"
[[ -z "$ARG" ]] && ARG="-n"

if [[ "$ARG" == "-n" ]]; then
    nohup mpv "$QUTE_URL" > /dev/null 2>&1 &
elif [[ "$ARG" == "-p" ]]; then
    nohup mpv "$QUTE_URL" --title="Picture-in-Picture" > /dev/null 2>&1 &
fi

exit 0
