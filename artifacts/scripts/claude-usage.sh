#!/usr/bin/env bash

CACHE="$HOME/.cache/claude-usage.json"

if [ ! -f "$CACHE" ]; then
  cat <<'EOF'
{"text":"󱙺 --% 7d:--%","tooltip":"No data yet — start a Claude session or wait for the timer"}
EOF
  exit 0
fi

five_pct=$(jq -r '.five_pct // empty' "$CACHE")
five_resets_at=$(jq -r '.five_resets_at // empty' "$CACHE")
week_pct=$(jq -r '.week_pct // empty' "$CACHE")
updated_at=$(jq -r '.updated_at // 0' "$CACHE")

now=$(date +%s)
age=$(( now - updated_at ))

if [ "$age" -lt 60 ]; then
  age_str="just now"
elif [ "$age" -lt 3600 ]; then
  age_str="$(( age / 60 ))m ago"
else
  age_str="$(( age / 3600 ))h ago"
fi

# Format display text
five_str="${five_pct:+$(printf '%.0f' "$five_pct")%}"
five_str="${five_str:---%}"
week_str="${week_pct:+$(printf '%.0f' "$week_pct")%}"
week_str="${week_str:---%}"

text="󱙺 ${five_str} 7d:${week_str}"

# Format reset time for tooltip
if [ -n "$five_resets_at" ] && [ "$five_resets_at" != "null" ]; then
  reset_time=$(date -d "@${five_resets_at}" +%H:%M 2>/dev/null)
  tooltip_line1="5hr: ${five_str} | Resets at ${reset_time:-?}"
else
  tooltip_line1="5hr: ${five_str}"
fi
tooltip="${tooltip_line1}"$'\n'"7d: ${week_str}"$'\n'"Last updated: ${age_str}"

# Add stale warning if cache is older than 30 minutes
if [ "$age" -gt 1800 ]; then
  text="${text} ?"
  tooltip="⚠ Stale data"$'\n'"${tooltip}"
fi

jq -n --arg text "$text" --arg tooltip "$tooltip" '{"text":$text,"tooltip":$tooltip}'
