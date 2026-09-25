#!/usr/bin/env bash
# Waybar module: report/toggle the hypridle caffeine state.
#
# Caffeine holds a systemd idle inhibitor (hypridle-caffeine.service); hypridle
# itself keeps running so it can still turn the screen back on and lock before
# sleep. Never stop hypridle.service to caffeinate.
#
# Usage:
#   hypridle-toggle.sh          # print current status as waybar JSON
#   hypridle-toggle.sh toggle   # flip caffeine on/off, then print status
#   hypridle-toggle.sh schedule # apply the time-based caffeine schedule

caffeinate() {
    systemctl --user start hypridle-caffeine.service
}

uncaffeinate() {
    systemctl --user stop hypridle-caffeine.service
    systemctl --user start hypridle.service
}

is_caffeinated() {
    systemctl --user --quiet is-active hypridle-caffeine.service
}

apply_schedule() {
    local hour minute minutes_since_midnight
    hour=$(date +%H)
    minute=$(date +%M)
    minutes_since_midnight=$((10#$hour * 60 + 10#$minute))

    if (( minutes_since_midnight >= 60 && minutes_since_midnight < 510 )); then
        caffeinate
    else
        uncaffeinate
    fi
}

status_json() {
    if is_caffeinated || ! pgrep -x hypridle > /dev/null; then
        echo '{"text": "󰅶", "tooltip": "Caffeinated (idle lock/sleep paused) — click to allow idle", "class": "disabled"}'
    else
        echo '{"text": "󰒲", "tooltip": "Idle lock/sleep enabled — click to caffeinate (stay awake)", "class": "enabled"}'
    fi
}

case "${1:-status}" in
    toggle)
        if is_caffeinated; then
            uncaffeinate
        else
            caffeinate
        fi
        ;;
    schedule)
        apply_schedule
        ;;
esac

status_json
