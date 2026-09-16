#!/usr/bin/env bash
# The old Waybar module also reads this file before the new generation is active.
if command -v notification-control >/dev/null 2>&1; then
    exec notification-control "${1:-status}"
fi
printf '%s\n' '{"text":"","tooltip":"Notification upgrade ready; activate the NixOS configuration","class":"disabled"}'
