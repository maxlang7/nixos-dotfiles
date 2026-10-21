#!/usr/bin/env bash
# Waybar module: report/toggle the wlsunset night-light process.

is_running() {
    pgrep -x wlsunset >/dev/null
}

start_wlsunset() {
    setsid -f wlsunset -t 1500 -T 6500 -s 21:00 -S 5:30
}

status_json() {
    if is_running; then
        echo '{"text":"󰖙","tooltip":"Night light enabled — click to disable","class":"enabled"}'
    else
        echo '{"text":"󰖔","tooltip":"Night light disabled — click to enable","class":"disabled"}'
    fi
}

case "${1:-status}" in
    toggle)
        if is_running; then
            pkill -x wlsunset
        else
            start_wlsunset
        fi
        ;;
esac

status_json
