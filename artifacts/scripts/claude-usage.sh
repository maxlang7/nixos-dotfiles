#!/usr/bin/env bash

SESSION_FILE="$HOME/.config/claude-session-key"
ORG="b7bd8c6b-87db-4377-8a93-3fc3b7dac255"

if [ ! -f "$SESSION_FILE" ]; then
  jq -cn '{"text":"󱙺 no key","tooltip":"Save session key to ~/.config/claude-session-key"}'
  exit 0
fi

SESSION=$(cat "$SESSION_FILE")

response=$(curl -sf \
  -H "Cookie: sessionKey=${SESSION}" \
  -H "Accept: application/json" \
  -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36" \
  -H "Referer: https://claude.ai/" \
  -H "sec-fetch-dest: empty" \
  -H "sec-fetch-mode: cors" \
  -H "sec-fetch-site: same-origin" \
  "https://claude.ai/api/organizations/${ORG}/usage" 2>/dev/null)

if [ -z "$response" ]; then
  jq -cn '{"text":"󱙺 error","tooltip":"Failed to reach claude.ai — check network or session key"}'
  exit 0
fi

five_pct=$(echo "$response" | jq -r '.five_hour.utilization // empty')
five_resets_at=$(echo "$response" | jq -r '.five_hour.resets_at // empty')
week_pct=$(echo "$response" | jq -r '.seven_day.utilization // empty')

five_str="${five_pct:+$(printf '%.0f' "$five_pct")%}"
five_str="${five_str:---%}"
week_str="${week_pct:+$(printf '%.0f' "$week_pct")%}"
week_str="${week_str:---%}"
five_resets_at_str="${five_resets_at_str:+$(printf '%.0f' "$week_pct")%}"
five_resets_at_str="${five_resets_at_str:---%}"

text="󱙺 ${five_str}"

if [ -n "$five_resets_at" ]; then
  reset_time=$(date -d "$five_resets_at" +"%I:%M %p" 2>/dev/null)  \
  text="󱙺 ${five_str}"
  tooltip_line1="5hr: ${five_str} | Resets at ${reset_time:-?}"
else
  tooltip_line1="5hr: ${five_str}"
fi
tooltip="${tooltip_line1}"$'\n'"7d: ${week_str}"

jq -cn --arg text "$text" --arg tooltip "$tooltip" '{"text":$text,"tooltip":$tooltip}'
