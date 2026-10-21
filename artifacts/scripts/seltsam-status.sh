#!/usr/bin/env bash
set -euo pipefail

interface=seltsam
link_info=$(ip -o link show dev "$interface" 2>/dev/null || true)

if [[ -z $link_info ]]; then
    jq -cn '{text:"",tooltip:"WireGuard seltsam is down",class:"disconnected"}'
    exit 0
fi

flags=${link_info#*<}
flags=${flags%%>*}
if [[ ",$flags," != *,UP,* ]]; then
    jq -cn '{text:"",tooltip:"WireGuard seltsam interface is down",class:"disconnected"}'
    exit 0
fi

routes=$(ip -4 route show dev "$interface" | awk '{print $1}' | paste -sd ',' -)
if [[ -n $routes ]]; then
    tooltip=$'WireGuard seltsam interface is up\nRoutes: '
    tooltip+=$routes
else
    tooltip="WireGuard seltsam interface is up; no IPv4 routes found"
fi

jq -cn --arg text '󰖂 VPN' --arg tooltip "$tooltip" \
    '{text:$text,tooltip:$tooltip,class:"connected"}'
