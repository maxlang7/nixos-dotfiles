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
  exit 0
fi

monitor_state=$(hyprctl monitors -j | jq -c 'map(select(.focused))[0] // .[0]')
regular_workspace=$(jq -r '.activeWorkspace.id' <<<"$monitor_state")
visible_special=$(jq -r '.specialWorkspace.name // ""' <<<"$monitor_state")
target_workspace=${visible_special:-$regular_workspace}

# Put the popup in the workspace that is already visible. If that is a special
# workspace, the existing scratchpad never has to hide or change focus.
hyprctl dispatch exec \
  "[workspace $target_workspace; float; size $popup_width $popup_height; center; dimaround] ghostty --title=$ghostty_title -e $popup_command" \
  >/dev/null
