#!/usr/bin/env bash

set -u

icon=${1:-󰚩}
auth_file=${GROK_AUTH_JSON:-$HOME/.grok/auth.json}
proxy=${GROK_CLI_CHAT_PROXY_BASE_URL:-https://cli-chat-proxy.grok.com/v1}
proxy=${proxy%/}

emit() {
  jq -cn \
    --arg text "$1" \
    --arg tooltip "$2" \
    --arg class "$3" \
    '{text:$text,tooltip:$tooltip,class:$class}'
}

markup() {
  printf '<span size="120%%">%s</span>\u2004<span rise="0.5pt">%s</span>' "$icon" "$1"
}

fail() {
  emit "$(markup "$1")" "Grok: $2" error
  exit 0
}

if ! command -v jq >/dev/null || ! command -v curl >/dev/null; then
  fail error "jq or curl is unavailable"
fi

if [[ ! -r "$auth_file" ]]; then
  fail "no key" "No Grok login in ${auth_file}"
fi

token_expiry_epoch() {
  local exp
  exp=$(jq -r 'to_entries[0].value.expires_at // empty' "$auth_file")
  [[ -z "$exp" ]] && { printf '0\n'; return; }
  date -d "$exp" +%s 2>/dev/null || printf '0\n'
}

needs_refresh() {
  local exp_s now
  exp_s=$(token_expiry_epoch)
  now=$(date +%s)
  (( exp_s < now + 120 ))
}

do_refresh() {
  local client refresh issuer tmp access new_refresh expires_in exp out
  client=$(jq -r 'to_entries[0].value.oidc_client_id // empty' "$auth_file")
  refresh=$(jq -r 'to_entries[0].value.refresh_token // empty' "$auth_file")
  issuer=$(jq -r 'to_entries[0].value.oidc_issuer // "https://auth.x.ai"' "$auth_file")
  issuer=${issuer%/}
  [[ -n "$client" && -n "$refresh" ]] || return 1
  tmp=$(mktemp)
  if ! curl -sf --max-time 15 -o "$tmp" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'grant_type=refresh_token' \
    --data-urlencode "refresh_token=${refresh}" \
    --data-urlencode "client_id=${client}" \
    "${issuer}/oauth2/token"; then
    rm -f "$tmp"
    return 1
  fi
  access=$(jq -r '.access_token // empty' "$tmp")
  new_refresh=$(jq -r '.refresh_token // empty' "$tmp")
  expires_in=$(jq -r '.expires_in // 3600' "$tmp")
  rm -f "$tmp"
  [[ -n "$access" ]] || return 1
  [[ -z "$new_refresh" ]] && new_refresh=$refresh
  exp=$(date -u -d "now + ${expires_in} seconds" '+%Y-%m-%dT%H:%M:%SZ')
  out=$(mktemp)
  if ! jq --arg key "$access" --arg refresh "$new_refresh" --arg exp "$exp" '
    (to_entries[0].key) as $id
    | .[$id].key = $key
    | .[$id].refresh_token = $refresh
    | .[$id].expires_at = $exp
  ' "$auth_file" >"$out"; then
    rm -f "$out"
    return 1
  fi
  mv "$out" "$auth_file"
}

refresh_locked() {
  exec 9>>"${auth_file}.lock"
  flock -w 8 9 || return 1
  do_refresh
}

if needs_refresh; then
  refresh_locked || fail error "Could not refresh the Grok login"
fi

token=$(jq -r 'to_entries[0].value.key // empty' "$auth_file")
[[ -n "$token" ]] || fail "no key" "Grok auth file has no access token"
email=$(jq -r 'to_entries[0].value.email // empty' "$auth_file")

body=$(mktemp)
code=$(curl -sS --max-time 12 -o "$body" -w '%{http_code}' \
  -H "Authorization: Bearer ${token}" \
  -H 'Accept: application/json' \
  -H 'User-Agent: grok/1.0.70' \
  -H 'x-grok-client-version: 1.0.70' \
  "${proxy}/billing?format=credits" || true)

if [[ "$code" == "401" ]]; then
  if refresh_locked; then
    token=$(jq -r 'to_entries[0].value.key // empty' "$auth_file")
    code=$(curl -sS --max-time 12 -o "$body" -w '%{http_code}' \
      -H "Authorization: Bearer ${token}" \
      -H 'Accept: application/json' \
      -H 'User-Agent: grok/1.0.70' \
      -H 'x-grok-client-version: 1.0.70' \
      "${proxy}/billing?format=credits" || true)
  fi
fi

if [[ "$code" != "200" ]] || ! jq -e '.config' >/dev/null 2>&1 <"$body"; then
  rm -f "$body"
  fail error "Could not read Grok usage"
fi

pct=$(jq -r '.config.creditUsagePercent // empty' "$body")
ptype=$(jq -r '.config.currentPeriod.type // empty' "$body")
pend=$(jq -r '.config.currentPeriod.end // .config.billingPeriodEnd // empty' "$body")
rm -f "$body"

pct_str="--%"
if [[ -n "$pct" ]]; then
  pct_str="$(printf '%.0f' "$pct")%"
fi

case "$ptype" in
  *DAILY*) window="Day" ;;
  *MONTHLY*) window="Month" ;;
  *) window="Week" ;;
esac

line="${window}: ${pct_str}"
if [[ -n "$pend" ]]; then
  reset_time=$(date -d "$pend" '+%a %I:%M %p' 2>/dev/null || true)
  [[ -n "$reset_time" ]] && line="${line} | Resets ${reset_time}"
fi

tooltip="Grok"
[[ -n "$email" ]] && tooltip="${tooltip}"$'\n'"${email}"
tooltip="${tooltip}"$'\n'"${line}"

class="normal"
if [[ -n "$pct" ]]; then
  if awk "BEGIN { exit !($pct >= 90) }"; then
    class="critical"
  elif awk "BEGIN { exit !($pct >= 70) }"; then
    class="warning"
  fi
fi

emit "$(markup "$pct_str")" "$tooltip" "$class"
