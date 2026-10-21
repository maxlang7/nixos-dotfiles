#!/usr/bin/env python3
"""Combined Wi-Fi and NixOS-managed WireGuard indicator for Waybar."""
import html
import json
import subprocess


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, check=False)
    return result.stdout.strip() if result.returncode == 0 else ""


devices = [line.split(":", 2) for line in run(
    "nmcli", "-t", "-e", "no", "-f", "DEVICE,TYPE,STATE", "device", "status"
).splitlines()]
wifi = next((dev for dev, kind, state in devices
             if kind == "wifi" and state == "connected"), None)
link = run("ip", "-o", "link", "show", "dev", "seltsam")
flags = link.partition("<")[2].partition(">")[0].split(",")
routes = run("ip", "-4", "route", "show", "dev", "seltsam") if "UP" in flags else ""
vpn = "UP" in flags and bool(routes)
tooltip = "VPN: seltsam interface up with routes" if vpn else "VPN: seltsam unavailable"
if routes:
    tooltip += "\n" + routes

if wifi:
    rows = run("nmcli", "-t", "-e", "no", "-f", "IN-USE,SSID,SIGNAL",
               "device", "wifi", "list", "ifname", wifi, "--rescan", "no")
    active = next((row[2:].rsplit(":", 1) for row in rows.splitlines()
                   if row.startswith("*:")), None)
    if active:
        ssid, strength = active
        label = f"{html.escape(ssid)} ({strength}%)"
    else:
        label = html.escape(run("nmcli", "-g", "GENERAL.CONNECTION",
                                "device", "show", wifi))
    # Material Design's wifi-lock is one glyph, so the VPN adds no extra item.
    icon = "󰤩" if vpn else ""
    text = f"<span size='166%' rise='-1.25pt'>{icon}</span> <span rise='1.25pt'>{label}</span>"
    tooltip = f"Wi-Fi: {label}\n" + html.escape(tooltip)
    state = "vpn" if vpn else "wifi"
elif any(kind == "ethernet" and state == "connected" for _, kind, state in devices):
    text = "󰈀" + (" 󰌾" if vpn else "")
    tooltip = "Ethernet\n" + html.escape(tooltip)
    state = "vpn" if vpn else "ethernet"
else:
    text = "<span size='166%' rise='-1.25pt'>󰖪</span>"
    tooltip = "Network disconnected\n" + html.escape(tooltip)
    state = "disconnected"

print(json.dumps({"text": text, "tooltip": tooltip, "class": state}))
