#!/usr/bin/env bash
# Inhibit hypridle when cursor is in ANY corner (with terminal output)
INHIBIT_PID=""
THRESHOLD=50

echo "Hot-corner script started. Move your cursor to any corner to test..."

while true; do
    POS=$(hyprctl cursorpos -j 2>/dev/null)
    CX=$(echo "$POS" | jq -r '.x // 0' | cut -d'.' -f1)
    CY=$(echo "$POS" | jq -r '.y // 0' | cut -d'.' -f1)

    MON=$(hyprctl monitors -j 2>/dev/null | jq '.[0]')
    W=$(echo "$MON" | jq '(.width / .scale) | floor')
    H=$(echo "$MON" | jq '(.height / .scale) | floor')

    # Detect which corner the cursor is in
    CURRENT_CORNER=""
    if [ "$CX" -le "$THRESHOLD" ] && [ "$CY" -le "$THRESHOLD" ]; then
        CURRENT_CORNER="Top-Left"
    elif [ "$CX" -ge "$((W - THRESHOLD))" ] && [ "$CY" -le "$THRESHOLD" ]; then
        CURRENT_CORNER="Top-Right"
    elif [ "$CX" -le "$THRESHOLD" ] && [ "$CY" -ge "$((H - THRESHOLD))" ]; then
        CURRENT_CORNER="Bottom-Left"
    elif [ "$CX" -ge "$((W - THRESHOLD))" ] && [ "$CY" -ge "$((H - THRESHOLD))" ]; then
        CURRENT_CORNER="Bottom-Right"
    fi

    # Handle inhibition based on corner status
    if [ -n "$CURRENT_CORNER" ]; then
        if [ -z "$INHIBIT_PID" ]; then
            echo "[+] Entered $CURRENT_CORNER corner (X: $CX, Y: $CY) -> Inhibiting idle"
            systemd-inhibit --what=idle --who="corner-inhibit" --why="Cursor in a hot corner" sleep infinity &
            INHIBIT_PID=$!
        fi
    else
        if [ -n "$INHIBIT_PID" ]; then
            echo "[-] Left the corner -> Idle inhibition lifted"
            kill "$INHIBIT_PID" 2>/dev/null
            INHIBIT_PID=""
        fi
    fi

    sleep 1
done
