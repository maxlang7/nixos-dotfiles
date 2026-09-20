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

# An exec rule applies before Ghostty maps the window. Unlike a dedicated
# special workspace, this keeps any currently visible scratchpad underneath.
hyprctl dispatch exec "[float; size $popup_width $popup_height; center; dimaround] ghostty --title=$ghostty_title -e $popup_command"
