#!/usr/bin/env bash
set -euo pipefail

# Shared by Waybar, Hypridle and Hyprland lid bindings. Keep Hypridle alive.
lid_closed() {
    local state
    for state in /proc/acpi/button/lid/*/state; do
        [[ -r "$state" ]] && [[ $(<"$state") == *closed* ]] && return 0
    done
    return 1
}
is_caffeinated() { systemctl --user --quiet is-active hypridle-caffeine.service; }
caffeinate() {
    systemctl --user start hypridle.service hypridle-caffeine.service
    if lid_closed; then lighting lid-close; fi
}
uncaffeinate() {
    systemctl --user stop hypridle-caffeine.service
    # Re-arm skipped lock/suspend deadlines with a fresh idle interval.
    # Restore saved lighting first, since restarting drops resume callbacks.
    lighting wake
    systemctl --user restart hypridle.service
    if lid_closed; then systemctl suspend; fi
}

lighting() (
    # Serialize lid and idle callbacks. A saved value belongs to the whole
    # dark interval, so a second reason for darkness cannot overwrite it.
    local action=$1 device value panel
    local state_dir="${XDG_RUNTIME_DIR:?}/hypridle-lighting"
    mkdir -p "$state_dir"
    exec 9>"$state_dir/lock"
    flock 9
    save_brightness() {
        device=$1
        if [[ ! -f "$state_dir/$device" ]]; then
            value=$(brightnessctl -d "$device" get)
            printf '%s\n' "$value" > "$state_dir/$device"
        fi
    }
    restore_brightness() {
        device=$1
        if [[ -f "$state_dir/$device" ]]; then
            value=$(<"$state_dir/$device")
            brightnessctl -d "$device" set "$value" >/dev/null
            unlink "$state_dir/$device"
        fi
    }
    internal_off() {
        while IFS= read -r panel; do
            [[ -n "$panel" ]] && hyprctl dispatch dpms off "$panel" >/dev/null
        done < <(hyprctl monitors all -j | jq -r '.[] | select(.name | startswith("eDP-")) | .name')
    }
    case "$action" in
        dim)
            if ! lid_closed; then
                save_brightness intel_backlight
                brightnessctl -d intel_backlight set 50%- >/dev/null
            fi ;;
        keyboard-off|lid-close)
            save_brightness chromeos::kbd_backlight
            brightnessctl -d chromeos::kbd_backlight set 0 >/dev/null
            if [[ "$action" == lid-close ]]; then
                # Prevent compositor input wake from relighting a closed panel.
                hyprctl keyword misc:key_press_enables_dpms false >/dev/null
                hyprctl keyword misc:mouse_move_enables_dpms false >/dev/null
                internal_off
            fi ;;
        display-off) hyprctl dispatch dpms off >/dev/null ;;
        restore-screen)
            if ! lid_closed; then restore_brightness intel_backlight; fi ;;
        restore-keyboard)
            if ! lid_closed; then restore_brightness chromeos::kbd_backlight; fi ;;
        wake|lid-open)
            hyprctl dispatch dpms on >/dev/null
            if lid_closed; then
                internal_off
            else
                hyprctl keyword misc:key_press_enables_dpms true >/dev/null
                hyprctl keyword misc:mouse_move_enables_dpms true >/dev/null
                restore_brightness intel_backlight
                restore_brightness chromeos::kbd_backlight
            fi
            # Do not hold the callback lock while Waybar settles.
            flock -u 9
            sleep 1
            pkill -USR2 -x waybar || true ;;
        *) return 2 ;;
    esac
)

status_json() {
    if ! systemctl --user --quiet is-active hypridle.service; then
        echo '{"text":"!","tooltip":"Hypridle is not running; idle handling unavailable","class":"error"}'
    elif is_caffeinated; then
        echo '{"text":"󰅶","tooltip":"Caffeinated: screen and keyboard sleep; work continues with lid closed. Click for normal idle.","class":"disabled"}'
    else
        echo '{"text":"󰒲","tooltip":"Normal idle: lock at 3 min, screen off at 5.5 min, suspend at 8 min 20 sec. Click to caffeinate.","class":"enabled"}'
    fi
}
case "${1:-status}" in
    toggle) if is_caffeinated; then uncaffeinate; else caffeinate; fi ;;
    caffeinate) caffeinate ;;
    uncaffeinate) uncaffeinate ;;
    idle-lock)
        if ! is_caffeinated; then loginctl lock-session; fi
        exit ;;
    idle-suspend)
        if ! is_caffeinated; then systemctl suspend; fi
        exit ;;
    # Compatibility for the old installed timer until the next activation.
    schedule) ;;
    dim|keyboard-off|display-off|restore-screen|restore-keyboard|wake|lid-open)
        lighting "$1"; exit ;;
    lid-close)
        # Also darken docked normal-mode sessions, where logind ignores the lid.
        lighting lid-close; exit ;;
    status) ;;
    *) exit 2 ;;
esac
status_json
