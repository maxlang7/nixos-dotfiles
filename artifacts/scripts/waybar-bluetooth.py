"""Waybar Bluetooth status, excluding BlueFerry's phone from text and tooltips."""
import html
import json
from pathlib import Path
import subprocess
import sys


def status(objects, phone_address=""):
    adapters = [v["org.bluez.Adapter1"] for v in objects.values()
                if "org.bluez.Adapter1" in v]
    powered = any(v.get("Powered", {}).get("data", False) for v in adapters)
    visible = []
    for interfaces in objects.values():
        device = interfaces.get("org.bluez.Device1", {})
        value = lambda key, default=None: device.get(key, {}).get("data", default)
        if not value("Connected", False):
            continue
        if (value("Address", "").upper() == phone_address.upper()
                or value("Icon", "") in {"phone", "audio-card-phone"}):
            continue
        alias = html.escape(value("Alias", "Bluetooth device"))
        battery = interfaces.get("org.bluez.Battery1", {}).get("Percentage", {}).get("data")
        visible.append((alias, battery))
    if visible:
        alias, battery = visible[0]
        text = f' {battery}%' if battery is not None else ''
        tooltip = "\n".join(name + (f" {level}%" if level is not None else "")
                            for name, level in visible)
        return {"text": text, "tooltip": tooltip, "class": "connected"}
    state = "on" if powered else "off"
    return {"text": f" {state}", "tooltip": f"Bluetooth {state}", "class": state}


def main():
    try:
        phone = Path("/run/secrets/blueferry-mac").read_text().strip()
    except OSError:
        phone = ""
    try:
        result = subprocess.run(
            [sys.argv[1], "--system", "--timeout=2", "--json=short", "call",
             "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"],
            check=True, capture_output=True, text=True, timeout=3)
        output = status(json.loads(result.stdout)["data"][0], phone)
    except (OSError, subprocess.SubprocessError, ValueError, KeyError):
        output = {"text": "", "tooltip": "Bluetooth status unavailable", "class": "unavailable"}
    print(json.dumps(output))


if __name__ == "__main__":
    main()
