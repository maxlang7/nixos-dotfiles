# shellcheck shell=bash

if (( $# < 4 )); then
  echo "usage: popup-launch TITLE WIDTH HEIGHT COMMAND [ARG ...]" >&2
  exit 2
fi

popup_title=$1
popup_width=$2
popup_height=$3
shift 3

if [[ ! $popup_width =~ ^[0-9]+$ || ! $popup_height =~ ^[0-9]+$ ]]; then
  echo "popup-launch: width and height must be pixel counts" >&2
  exit 2
fi

printf -v popup_command '%q ' "$@"
printf -v ghostty_title '%q' "$popup_title"

existing_address=$(hyprctl clients -j | jq -r --arg title "$popup_title" \
  '.[] | select(.title == $title) | .address' | head -n 1)
if [[ -n $existing_address ]]; then
  hyprctl dispatch focuswindow "address:$existing_address" >/dev/null
  exit 0
fi

monitor_state=$(hyprctl monitors -j | jq -c 'map(select(.focused))[0] // .[0]')
regular_workspace=$(jq -r '.activeWorkspace.id' <<<"$monitor_state")
visible_special=$(jq -r '.specialWorkspace.name // ""' <<<"$monitor_state")

# Pinning lets a regular-workspace client remain above a visible special
# workspace. A normal floating client would focus the regular workspace and
# hide the scratchpad that was already open.
hyprctl dispatch exec \
  "[workspace $regular_workspace; float; pin; size $popup_width $popup_height; center; dimaround] ghostty --title=$ghostty_title -e $popup_command" \
  >/dev/null

popup_address=""
for _ in {1..50}; do
  popup_address=$(hyprctl clients -j | jq -r --arg title "$popup_title" \
    '.[] | select(.title == $title) | .address' | head -n 1)
  [[ -n $popup_address ]] && break
  sleep 0.1
done

if [[ -z $popup_address ]]; then
  echo "popup-launch: $popup_title did not create a window" >&2
  exit 1
fi

hyprctl dispatch focuswindow "address:$popup_address" >/dev/null

while hyprctl clients -j | jq -e --arg address "$popup_address" \
  'any(.[]; .address == $address)' >/dev/null; do
  sleep 0.2
done

# Closing a pinned client can return focus to the regular workspace and hide
# the special workspace below it. Restore only the scratchpad we found at
# launch, and only when no other special workspace has replaced it.
if [[ -n $visible_special ]]; then
  current_special=$(hyprctl monitors -j | jq -r 'map(select(.focused))[0].specialWorkspace.name // ""')
  if [[ -z $current_special ]]; then
    hyprctl dispatch togglespecialworkspace "${visible_special#special:}" >/dev/null
  fi
fi
