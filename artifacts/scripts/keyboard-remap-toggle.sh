#!/usr/bin/env bash
set -euo pipefail
keymap=/etc/nixos/artifacts/xkb/enter-backspace.xkb
current_map() { hyprctl -j getoption input:kb_file | jq -er '.str'; }
if [[ ${1:-status} == lock ]]; then
    # Hold the same lock as the toggle until the locker exits. Never allow
    # another lock request to restore the layout underneath an existing lock.
    exec 9>"${XDG_RUNTIME_DIR:?}/keyboard-remap-toggle.lock"
    flock -n 9 || exit 0
    if pidof hyprlock >/dev/null; then exit 0; fi
    if ! previous=$(current_map); then
        exec hyprlock
    fi
    [[ $previous != '[[EMPTY]]' ]] || previous=""
    restore_map() { hyprctl keyword input:kb_file "$previous" >/dev/null || true; }
    trap restore_map EXIT
    # A remapping failure must never prevent the screen from locking.
    hyprctl keyword input:kb_file "$keymap" >/dev/null || true
    hyprlock
    exit $?
fi
if [[ ${1:-status} == toggle ]]; then
    # Avoid racing two clicks. Read Hyprland's actual state, not a saved flag.
    exec 9>"${XDG_RUNTIME_DIR:?}/keyboard-remap-toggle.lock"
    flock 9
    current=$(current_map)
    if [[ $current == "$keymap" ]]; then
        hyprctl keyword input:kb_file "" >/dev/null
    elif [[ -z $current || $current == '[[EMPTY]]' ]]; then
        hyprctl keyword input:kb_file "$keymap" >/dev/null
    else
        # Do not overwrite a different custom keyboard map.
        printf 'Another custom keyboard map is active: %s\n' "$current" >&2
        exit 1
    fi
elif [[ ${1:-status} != status ]]; then
    exit 2
fi
if [[ $(current_map) == "$keymap" ]]; then
    printf '%s\n' '{"text":"󰌑","class":"enabled","tooltip":"Key remap ON: Right Shift → Enter; \\ | → Backspace. Original Enter and Backspace still work. Click to restore normal keys."}'
else
    printf '%s\n' '{"text":"󰌌","class":"disabled","tooltip":"Key remap OFF. Click for Right Shift → Enter and \\ | → Backspace. Original Enter and Backspace still work."}'
fi
