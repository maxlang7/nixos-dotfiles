#!/usr/bin/env bash
# Waybar module: report and toggle Dunst's paused state.

if [ "${1:-}" = "toggle" ]; then
    dunstctl set-paused toggle > /dev/null
fi

case "$(dunstctl is-paused 2>/dev/null)" in
    false)
        printf '%s\n' '{"text":"","tooltip":"Notifications are on - click to pause","class":"enabled"}'
        ;;
    true)
        printf '%s\n' '{"text":"","tooltip":"Notifications are paused - click to resume","class":"disabled"}'
        ;;
    *)
        printf '%s\n' '{"text":"","tooltip":"Could not read notification status","class":"error"}'
        ;;
esac
