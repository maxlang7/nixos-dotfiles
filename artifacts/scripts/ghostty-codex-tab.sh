#!/usr/bin/env bash
set -euo pipefail

# This shortcut is meant to work only while a Ghostty window has focus.
if ! hyprctl activewindow -j | jq -e '((.class // "") | ascii_downcase | contains("ghostty"))' >/dev/null; then
  exit 0
fi

# Let Hyprland release the physical chord before synthesizing Ghostty's
# default new-tab shortcut, then wait for the new shell before typing Codex.
sleep 0.25
wtype -M ctrl -M shift -k t
sleep 0.25
wtype codex
wtype -k Return
