#!/usr/bin/env bash

set -u

error_json() {
  jq -cn --arg message "$1" \
    '{text:">_ error",tooltip:$message,class:"error"}'
}

if ! command -v codex >/dev/null || ! command -v jq >/dev/null; then
  error_json "Codex or jq is unavailable"
  exit 0
fi

coproc CODEX_USAGE_SERVER { codex app-server 2>/dev/null; }
server_pid=$CODEX_USAGE_SERVER_PID
server_out=${CODEX_USAGE_SERVER[0]}
server_in=${CODEX_USAGE_SERVER[1]}

cleanup() {
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT

printf '%s\n' \
  '{"method":"initialize","id":0,"params":{"clientInfo":{"name":"waybar_codex_usage","title":"Waybar Codex Usage","version":"1.0.0"}}}' \
  '{"method":"initialized","params":{}}' \
  '{"method":"account/rateLimits/read","id":1}' \
  >&$server_in

result=""
while IFS= read -r -t 5 -u "$server_out" line; do
  if jq -e '.id == 1 and .result != null' >/dev/null 2>&1 <<<"$line"; then
    result=$(jq -c '.result' <<<"$line")
    break
  fi
done

if [ -z "$result" ]; then
  error_json "Could not read Codex account limits"
  exit 0
fi

snapshot=$(jq -c '.rateLimitsByLimitId.codex // .rateLimits // empty' <<<"$result")
if [ -z "$snapshot" ]; then
  error_json "Codex did not return a rate-limit window"
  exit 0
fi

five=$(jq -c \
  '[.primary, .secondary] | map(select(.windowDurationMins == 300)) | first // empty' \
  <<<"$snapshot")
week=$(jq -c \
  '[.primary, .secondary] | map(select(.windowDurationMins == 10080)) | first // empty' \
  <<<"$snapshot")

five_pct=$(jq -r '.usedPercent // empty' <<<"$five")
five_reset=$(jq -r '.resetsAt // empty' <<<"$five")
week_pct=$(jq -r '.usedPercent // empty' <<<"$week")
week_reset=$(jq -r '.resetsAt // empty' <<<"$week")
plan=$(jq -r '.planType // empty' <<<"$snapshot")

five_str="--%"
week_str="--%"
[ -n "$five_pct" ] && five_str="$(printf '%.0f' "$five_pct")%"
[ -n "$week_pct" ] && week_str="$(printf '%.0f' "$week_pct")%"

tooltip_line1="5hr: $five_str"
tooltip_line2="7d: $week_str"
if [ -n "$five_reset" ]; then
  reset_time=$(date -d "@$five_reset" '+%I:%M %p' 2>/dev/null || true)
  [ -n "$reset_time" ] && tooltip_line1="$tooltip_line1 | Resets at $reset_time"
fi
if [ -n "$week_reset" ]; then
  reset_time=$(date -d "@$week_reset" '+%a %I:%M %p' 2>/dev/null || true)
  [ -n "$reset_time" ] && tooltip_line2="$tooltip_line2 | Resets $reset_time"
fi

tooltip="$tooltip_line1"$'\n'"$tooltip_line2"
[ -n "$plan" ] && tooltip="$tooltip"$'\n'"Plan: ${plan^}"

class="normal"
if [ -n "$five_pct" ]; then
  if awk "BEGIN { exit !($five_pct >= 90) }"; then
    class="critical"
  elif awk "BEGIN { exit !($five_pct >= 70) }"; then
    class="warning"
  fi
fi

jq -cn \
  --arg text "󰆍 $five_str" \
  --arg tooltip "$tooltip" \
  --arg class "$class" \
  '{text:$text,tooltip:$tooltip,class:$class}'
