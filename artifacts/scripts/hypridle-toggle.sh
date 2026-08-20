#!/usr/bin/env bash
# Waybar module: report/toggle whether hypridle is running.
#
# Usage:
#   hypridle-toggle.sh          # print current status as waybar JSON
#   hypridle-toggle.sh toggle   # start/stop hypridle, then print status

status_json() {
    if pgrep -x hypridle > /dev/null; then
        echo '{"text": "󰒲", "tooltip": "hypridle is enabled — click to disable (stay awake)", "class": "enabled"}'
    else
        echo '{"text": "󰅶", "tooltip": "hypridle is disabled — click to enable (allow idle/lock/sleep)", "class": "disabled"}'
    fi
}

if [ "$1" = "toggle" ]; then
    if pgrep -x hypridle > /dev/null; then
        pkill -x hypridle
    else
        nohup hypridle > /dev/null 2>&1 &
        disown
    fi
fi

status_json
