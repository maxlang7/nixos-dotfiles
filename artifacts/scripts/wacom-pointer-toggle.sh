#!/usr/bin/env bash

# Waybar control for the Wacom Intuos CTL-6100WL. In mouse mode the USB
# device itself is deauthorized, so neither its pen nor ExpressKeys can act.

set -u

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
applied_file="$runtime_dir/wacom-pointer-applied"

find_wacom_usb() {
  local device
  for device in /sys/bus/usb/devices/*; do
    [[ -r "$device/idVendor" && -r "$device/idProduct" ]] || continue
    [[ $(<"$device/idVendor") == 056a ]] || continue
    [[ $(<"$device/idProduct") == 03c7 ]] || continue
    printf '%s\n' "$device"
    return 0
  done
  return 1
}

load_hyprland_devices() {
  local devices_json
  devices_json=$(hyprctl devices -j 2>/dev/null) || devices_json='{"mice":[],"tablets":[]}'

  mapfile -t tablet_names < <(
    jq -r '.tablets[] | select(.name? and (.name | ascii_downcase | contains("wacom"))) | .name' \
      <<<"$devices_json"
  )
  mapfile -t mouse_names < <(jq -r '.mice[].name' <<<"$devices_json")
}

set_device_enabled() {
  local name=$1
  local value=$2
  hyprctl keyword "device[$name]:enabled" "$value" >/dev/null 2>&1 || true
}

reconcile() {
  local usb_device=${1:-}
  local authorized=${2:-0}
  local pen_ready=false
  local tablet_state=false
  local mouse_state=true

  load_hyprland_devices

  if [[ $authorized == 1 ]] && ((${#tablet_names[@]})); then
    pen_ready=true
    tablet_state=true
  fi

  local signature="$usb_device:$authorized:$pen_ready:${tablet_names[*]}:${mouse_names[*]}"
  if [[ ! -r "$applied_file" ]] || [[ $(<"$applied_file") != "$signature" ]]; then
    local name
    for name in "${tablet_names[@]}"; do
      set_device_enabled "$name" "$tablet_state"
    done
    for name in "${mouse_names[@]}"; do
      set_device_enabled "$name" "$mouse_state"
    done
    printf '%s\n' "$signature" >"$applied_file"
  fi

  if [[ -z $usb_device ]]; then
    return
  fi

  if [[ $authorized == 1 ]]; then
    jq -cn '{text:"󰏪", class:"enabled", tooltip:"Wacom USB enabled; touchpad remains available"}'
  else
    jq -cn '{text:"󰍽", class:"disabled", tooltip:"Wacom USB disabled; click to enable the pen"}'
  fi
}

usb_device=$(find_wacom_usb) || usb_device=
authorized=0
if [[ -n $usb_device && -r "$usb_device/authorized" ]]; then
  authorized=$(<"$usb_device/authorized")
fi

case "${1:-status}" in
  toggle)
    [[ -n $usb_device ]] || exit 0

    if [[ $authorized == 1 ]]; then
      # Restore ordinary pointers before removing the active pen.
      reconcile "$usb_device" 0 >/dev/null
      sudo -n /run/current-system/sw/bin/wacom-usb-power disable
      authorized=0
    else
      sudo -n /run/current-system/sw/bin/wacom-usb-power enable
      authorized=1
    fi

    rm -f "$applied_file"
    reconcile "$usb_device" "$authorized"
    ;;
  status)
    reconcile "$usb_device" "$authorized"
    ;;
  *)
    printf 'usage: %s [status|toggle]\n' "$0" >&2
    exit 2
    ;;
esac
