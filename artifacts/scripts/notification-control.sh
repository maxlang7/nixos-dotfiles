# Packaged by notifications.nix with a fixed PATH and base configuration.
set -euo pipefail
runtime="${XDG_RUNTIME_DIR:?}/notification-center"
mkdir -p "$runtime"
config="$runtime/config.json"

write_config() {
    cp "$NOTIFICATIONS_BASE_CONFIG" "$config.new"
    mv -f "$config.new" "$config"
}

case "${1:-status}" in
    session-start)
        systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
        exec systemctl --user start swaync.service
        ;;
    start)
        write_config
        exec swaync --config "$config" --style "$NOTIFICATIONS_STYLE"
        ;;
    toggle)
        state=$(swaync-client --skip-wait --toggle-dnd)
        if [[ "$state" == true ]]; then
            swaync-client --skip-wait --hide-all >/dev/null
        fi
        ;;
    history)
        swaync-client --skip-wait --toggle-panel
        ;;
    status)
        if ! state=$(swaync-client --skip-wait --get-dnd 2>/dev/null); then
            printf '%s\n' '{"text":"","tooltip":"Notification center is not running","class":"error"}'
            exit 0
        fi
        icon=''; class=enabled; label='Notifications on'
        if [[ "$state" == true ]]; then
            icon=''; class=disabled; label='Quiet mode'
        fi
        text="$icon"
        jq -nc --arg text "$text" --arg class "$class" \
            --arg tooltip "$label\nLeft-click: quiet mode\nRight-click: history" \
            '{text:$text, class:$class, tooltip:($tooltip | gsub("\\\\n"; "\n"))}'
        ;;
    *) printf 'Usage: notification-control {toggle|history|status|start|session-start}\n' >&2; exit 2 ;;
esac
