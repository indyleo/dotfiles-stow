#!/bin/env bash

PROCESS_NAME="qs"

echo "Watchdog started for $PROCESS_NAME... (Press [CTRL+C] to stop)"

while true
do
    if pgrep -x "$PROCESS_NAME" > /dev/null
    then
        # It's running, do nothing
        sleep 5
    else
        echo "[$(date)]: $PROCESS_NAME crashed or closed. Restarting..."
        $PROCESS_NAME &
        sleep 2.5 # Give it a moment to boot up
    fi
done
