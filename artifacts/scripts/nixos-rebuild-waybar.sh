#!/usr/bin/env bash
# The terminal worker owns the lock, not Ghostty's short-lived launcher.
set -u

state_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/waybar-nixos-rebuild"
state_file="$state_dir/state"
lock_file="$state_dir/worker.lock"
mkdir -p "$state_dir"

is_active() {
    ! flock -n "$lock_file" true
}

status() {
    local frame="${1:-0}" state="idle" text="󱄅" tooltip
    local frames=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
    tooltip=$'Left-click: fingerprint and rebuild\nRight-click: update flake and rebuild'
    if is_active; then
        [[ -r "$state_file" ]] && IFS= read -r state < "$state_file"
        text="${frames[frame % ${#frames[@]}]}"
        if [[ "$state" == authenticating ]]; then
            tooltip="Waiting for fingerprint verification in the NixOS terminal"
        else
            state="running"
            tooltip="NixOS rebuild in progress. See the NixOS terminal for output."
        fi
    fi
    jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$state" \
        '{text:$text,tooltip:$tooltip,class:$class}'
}

watch_status() {
    local frame=0
    while :; do
        status "$frame" || return
        frame=$(( (frame + 1) % 10 ))
        if is_active; then sleep 0.12; else sleep 1; fi
    done
}

release_lock() {
    printf 'idle\n' > "$state_file"
    flock -u 9
    exec 9>&-
}

draw_header() {
    local mode="${1:-switch}" columns pad line label="REBUILD SYSTEM"
    [[ "$mode" == update ]] && label="UPDATE + REBUILD"
    columns=$(tput cols 2>/dev/null || printf '50')
    # Center the logo and labels using the actual terminal width.
    printf '\033[2J\033[H'
    while IFS= read -r line; do
        pad=$(( (columns - 40) / 2 ))
        (( pad < 0 )) && pad=0
        printf '%*s\033[38;2;126;186;228m%s\033[0m\n' "$pad" '' "$line"
    done <<'LOGO'
          ▗▄▄▄       ▗▄▄▄▄    ▄▄▄▖
          ▜███▙       ▜███▙  ▟███▛
           ▜███▙       ▜███▙▟███▛
            ▜███▙       ▜██████▛
     ▟█████████████████▙ ▜████▛     ▟▙
    ▟███████████████████▙ ▜███▙    ▟██▙
           ▄▄▄▄▖           ▜███▙  ▟███▛
          ▟███▛             ▜██▛ ▟███▛
         ▟███▛               ▜▛ ▟███▛
▟███████████▛                  ▟██████████▙
▜██████████▛                  ▟███████████▛
      ▟███▛ ▟▙               ▟███▛
     ▟███▛ ▟██▙             ▟███▛
    ▟███▛  ▜███▙           ▝▀▀▀▀
    ▜██▛    ▜███▙ ▜██████████████████▛
     ▜▛     ▟████▙ ▜████████████████▛
           ▟██████▙       ▜███▙
          ▟███▛▜███▙       ▜███▙
         ▟███▛  ▜███▙       ▜███▙
         ▝▀▀▀    ▀▀▀▀▘       ▀▀▀▘
LOGO
    printf '\n'
    for line in "N I X O S   /   A R A G O R N" "$label"; do
        pad=$(( (columns - ${#line}) / 2 ))
        (( pad < 0 )) && pad=0
        printf '%*s\033[1m%s\033[0m\n' "$pad" '' "$line"
    done
    line='Touch the fingerprint reader'
    pad=$(( (columns - ${#line}) / 2 ))
    (( pad < 0 )) && pad=0
    printf '%*s\033[38;2;146;131;116m%s\033[0m\n' "$pad" '' "$line"
}

worker() {
    local mode="${1:-switch}" result=0 window address="" workspace=""
    exec 9>"$lock_file"
    # Allow a concurrent status probe to release its momentary lock.
    if ! flock -w 0.1 9; then
        notify-send "NixOS rebuild" "A rebuild or fingerprint check is already running." || true
        return 0
    fi
    trap release_lock EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP
    printf 'authenticating\n' > "$state_file"
    draw_header "$mode"
    # Authenticate in this terminal, then reuse its sudo timestamp without prompts.
    if sudo -v; then
        window=$(hyprctl clients -j | jq -c '[.[] | select(.title == "NixOS-rebuild")][0] // {}')
        address=$(jq -r '.address // empty' <<<"$window")
        workspace=$(jq -r '.workspace.name // empty' <<<"$window")
        if [[ -n "$address" && -n "$workspace" ]]; then
            hyprctl dispatch movetoworkspacesilent "special:nixos-rebuild,address:$address" >/dev/null || true
        fi
        printf 'running\n' > "$state_file"
        if [[ "$mode" == update ]]; then
            sudo -n bash -c 'nix flake update --flake /etc/nixos && nixos-rebuild switch --flake /etc/nixos#Aragorn' || result=$?
        else
            sudo -n nixos-rebuild switch --flake /etc/nixos#Aragorn || result=$?
        fi
    else
        result=$?
    fi
    # Release before waiting for Enter: leaving the output open is not a build.
    release_lock
    trap - EXIT INT TERM HUP
    if (( result == 0 )); then
        printf '\nRebuild completed successfully.\n'
        notify-send "NixOS rebuild" "Rebuild completed successfully." || true
        return 0
    else
        if [[ -n "$address" && -n "$workspace" ]]; then
            hyprctl dispatch movetoworkspace "$workspace,address:$address" >/dev/null || true
        fi
        printf '\nRebuild did not complete, exit code %s. See output above.\n' "$result"
        notify-send "NixOS rebuild" "Rebuild did not complete. See the terminal for details." || true
    fi
    printf '\nPress Enter to close.'
    read -r _ || true
    return "$result"
}

start() {
    local mode="${1:-switch}"
    if is_active; then
        notify-send "NixOS rebuild" "A rebuild or authentication is already running." || true
        return 0
    fi
    # Use the same visible-workspace handling as the Wi-Fi and audio popups.
    popup-launch NixOS-rebuild 560 560 "$0" worker "$mode"
}

case "${1:-status}" in
    status) status ;;
    watch) watch_status ;;
    start) start switch ;;
    update) start update ;;
    worker) worker "${2:-switch}" ;;
    preview) draw_header "${2:-switch}"; read -r _ ;;
    *) printf 'Usage: %s [status|watch|start|update|worker]\n' "$0" >&2; exit 2 ;;
esac
