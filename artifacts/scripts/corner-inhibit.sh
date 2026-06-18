#!/usr/bin/env bash
# Inhibit hypridle when cursor is in the bottom-right corner
INHIBIT_PID=""
THRESHOLD=50

while true; do
    POS=$(hyprctl cursorpos -j 2>/dev/null)
    CX=$(echo "$POS" | jq -r '.x // 0' | cut -d'.' -f1)
    CY=$(echo "$POS" | jq -r '.y // 0' | cut -d'.' -f1)

    MON=$(hyprctl monitors -j 2>/dev/null | jq '.[0]')
    W=$(echo "$MON" | jq '(.width / .scale) | floor')
    H=$(echo "$MON" | jq '(.height / .scale) | floor')

    if [ "$CX" -ge "$((W - THRESHOLD))" ] && [ "$CY" -ge "$((H - THRESHOLD))" ]; then
        if [ -z "$INHIBIT_PID" ]; then
            systemd-inhibit --what=idle --who="corner-inhibit" --why="Cursor in bottom-right corner" sleep infinity &
            INHIBIT_PID=$!
        fi
    else
        if [ -n "$INHIBIT_PID" ]; then
            kill "$INHIBIT_PID" 2>/dev/null
            INHIBIT_PID=""
        fi
    fi

    sleep 1
done
