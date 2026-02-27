#!/bin/env bash
# This script sends the current URL to mpv
# Requires: mpv and yt-dlp

if [ -z "$QUTE_URL" ]; then
    exit 1
fi

# Use nohup to allow mpv to keep running if you close the tab
nohup mpv "$QUTE_URL" > /dev/null 2>&1 &
