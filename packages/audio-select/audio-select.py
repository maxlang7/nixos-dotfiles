#!/usr/bin/env python3

import argparse
import curses
import os
import re
import subprocess
import tempfile
import textwrap
from dataclasses import dataclass
from pathlib import Path


TEST_TRACK = Path(
    os.environ.get(
        "AUDIO_SELECT_TEST_TRACK",
        "/home/maxlang/Music/test/04 Portugal. The Man - Feel It Still.m4a",
    )
)
TEST_TRACK_START = 35
TEST_SECONDS = 5
TEST_FRAMES = 48_000 * TEST_SECONDS


@dataclass(frozen=True)
class Node:
    id: int
    name: str
    default: bool = False


@dataclass(frozen=True)
class WifiNetwork:
    ssid: str
    signal: int
    security: str
    active: bool
    profile_uuid: str | None = None

    @property
    def id(self):
        return self.ssid

    @property
    def name(self):
        security = self.security or "Open"
        return f"{self.ssid}  {self.signal}%  {security}"

    @property
    def default(self):
        return self.active


@dataclass(frozen=True)
class VpnProfile:
    uuid: str
    profile_name: str
    kind: str
    active: bool

    @property
    def id(self):
        return self.uuid

    @property
    def name(self):
        label = "WireGuard" if self.kind == "wireguard" else "VPN"
        return f"{self.profile_name}  {label}"

    @property
    def default(self):
        return self.active


@dataclass(frozen=True)
class BluetoothDevice:
    address: str
    alias: str
    paired: bool
    trusted: bool
    connected: bool
    blocked: bool
    battery: int | None = None

    @property
    def id(self):
        return self.address

    @property
    def name(self):
        flags = []
        if self.connected:
            flags.append("connected")
        elif self.paired:
            flags.append("paired")
        else:
            flags.append("new")
        if self.trusted:
            flags.append("trusted")
        if self.battery is not None:
            flags.append(f"{self.battery}%")
        return f"{self.alias}  {' · '.join(flags)}"

    @property
    def default(self):
        return self.connected


@dataclass(frozen=True)
class PowerAction:
    id: str
    name: str
    command: tuple[str, ...]
    confirm: bool = True

    @property
    def default(self):
        return False


POWER_ACTIONS = (
    PowerAction("lock", "Lock screen", ("hyprlock",), False),
    PowerAction("suspend", "Suspend", ("systemctl", "suspend")),
    PowerAction("hibernate", "Hibernate", ("systemctl", "hibernate")),
    PowerAction("logout", "Log out of Hyprland", ("hyprctl", "dispatch", "exit")),
    PowerAction("reboot", "Restart computer", ("systemctl", "reboot")),
    PowerAction("poweroff", "Shut down computer", ("systemctl", "poweroff")),
)


def run(command, *, check=True, input_text=None):
    return subprocess.run(
        command,
        check=check,
        text=True,
        input=input_text,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def split_nmcli(line):
    fields = []
    current = []
    escaped = False
    for character in line:
        if escaped:
            current.append(character)
            escaped = False
        elif character == "\\":
            escaped = True
        elif character == ":":
            fields.append("".join(current))
            current = []
        else:
            current.append(character)
    if escaped:
        current.append("\\")
    fields.append("".join(current))
    return fields


def parse_wifi_rows(output, profiles):
    strongest = {}
    for line in output.splitlines():
        fields = split_nmcli(line)
        if len(fields) != 4:
            continue
        in_use, ssid, signal, security = fields
        if not ssid:
            continue
        try:
            strength = int(signal)
        except ValueError:
            continue
        network = WifiNetwork(
            ssid=ssid,
            signal=strength,
            security=security,
            active=in_use == "*",
            profile_uuid=profiles.get(ssid),
        )
        previous = strongest.get(ssid)
        if previous is None or network.active or strength > previous.signal:
            strongest[ssid] = network
    return sorted(strongest.values(), key=lambda item: (not item.active, -item.signal, item.ssid.lower()))


def get_connection_rows():
    result = run(
        [
            "nmcli", "-t", "--escape", "yes",
            "-f", "NAME,UUID,TYPE,DEVICE,ACTIVE", "connection", "show",
        ]
    )
    rows = []
    for line in result.stdout.splitlines():
        fields = split_nmcli(line)
        if len(fields) == 5:
            rows.append(fields)
    return rows


def get_saved_wifi_profiles(connection_rows):
    profiles = {}
    for _, uuid, kind, _, active in connection_rows:
        if kind != "802-11-wireless":
            continue
        result = run(
            ["nmcli", "-g", "802-11-wireless.ssid", "connection", "show", "uuid", uuid],
            check=False,
        )
        ssid = result.stdout.strip()
        if ssid and (ssid not in profiles or active == "yes"):
            profiles[ssid] = uuid
    return profiles


def get_networks(*, rescan=False):
    connection_rows = get_connection_rows()
    profiles = get_saved_wifi_profiles(connection_rows)
    wifi_output = run(
        [
            "nmcli", "-t", "--escape", "yes",
            "-f", "IN-USE,SSID,SIGNAL,SECURITY",
            "device", "wifi", "list", "--rescan", "yes" if rescan else "no",
        ]
    ).stdout
    wifi = parse_wifi_rows(wifi_output, profiles)
    vpns = [
        VpnProfile(uuid=uuid, profile_name=name, kind=kind, active=active == "yes")
        for name, uuid, kind, _, active in connection_rows
        if kind in ("vpn", "wireguard")
    ]
    vpns.sort(key=lambda item: (not item.active, item.profile_name.lower()))
    return wifi, vpns


def parse_bluetooth_info(address, output):
    values = {}
    for line in output.splitlines():
        key, separator, value = line.strip().partition(":")
        if separator:
            values[key] = value.strip()
    battery_tokens = values.get("Battery Percentage", "").split()
    try:
        battery_percent = int(battery_tokens[0].strip("()"), 0)
    except (IndexError, ValueError):
        battery_percent = None
    return BluetoothDevice(
        address=address,
        alias=values.get("Alias") or values.get("Name") or address,
        paired=values.get("Paired") == "yes",
        trusted=values.get("Trusted") == "yes",
        connected=values.get("Connected") == "yes",
        blocked=values.get("Blocked") == "yes",
        battery=battery_percent,
    )


def get_bluetooth_devices():
    result = run(["bluetoothctl", "devices"], check=False)
    devices = []
    for line in result.stdout.splitlines():
        match = re.match(r"Device\s+([0-9A-Fa-f:]{17})\s+", line)
        if not match:
            continue
        address = match.group(1)
        info = run(["bluetoothctl", "info", address], check=False)
        if info.returncode == 0:
            devices.append(parse_bluetooth_info(address, info.stdout))
    return sorted(devices, key=lambda item: (not item.connected, not item.paired, item.alias.lower()))


def bluetooth_powered():
    return "Powered: yes" in run(["bluetoothctl", "show"], check=False).stdout


def parse_status(status):
    outputs = []
    inputs = []
    section = None
    in_audio = False

    for line in status.splitlines():
        if line == "Audio":
            in_audio = True
            continue
        if in_audio and line == "Video":
            break
        if not in_audio:
            continue

        if "Sinks:" in line:
            section = outputs
            continue
        if "Sources:" in line:
            section = inputs
            continue
        if any(label in line for label in ("Devices:", "Filters:", "Streams:")):
            section = None
            continue
        if section is None:
            continue

        match = re.search(r"(?P<default>\*)?\s*(?P<id>\d+)\.\s+(?P<name>.*?)\s*(?:\[[^]]*\])?\s*$", line)
        if not match:
            continue
        name = match.group("name").strip()
        if name:
            section.append(
                Node(
                    id=int(match.group("id")),
                    name=name,
                    default=match.group("default") == "*",
                )
            )

    return outputs, inputs


def get_nodes():
    return parse_status(run(["wpctl", "status"]).stdout)


def is_muted(node_id):
    result = run(["wpctl", "get-volume", str(node_id)], check=False)
    return "MUTED" in result.stdout


def set_muted(node_id, muted):
    run(["wpctl", "set-mute", str(node_id), "1" if muted else "0"])


def clipped(text, width):
    if width <= 0:
        return ""
    if len(text) <= width:
        return text
    if width == 1:
        return text[:1]
    return text[: width - 1] + "…"


def init_theme():
    curses.curs_set(0)
    curses.use_default_colors()
    if curses.COLORS >= 256:
        # Gruvbox dark: cream on dark gray, with purple, blue, and green accents.
        curses.init_pair(1, 223, 235)
        curses.init_pair(2, 235, 66)
        curses.init_pair(3, 132, 235)
        curses.init_pair(4, 235, 106)
        curses.init_pair(5, 245, 235)
    else:
        curses.init_pair(1, curses.COLOR_WHITE, curses.COLOR_BLACK)
        curses.init_pair(2, curses.COLOR_BLACK, curses.COLOR_BLUE)
        curses.init_pair(3, curses.COLOR_MAGENTA, curses.COLOR_BLACK)
        curses.init_pair(4, curses.COLOR_BLACK, curses.COLOR_GREEN)
        curses.init_pair(5, curses.COLOR_WHITE, curses.COLOR_BLACK)


class AudioSelect:
    def __init__(self, screen):
        self.screen = screen
        self.outputs = []
        self.inputs = []
        self.output_index = 0
        self.input_index = 0
        self.focus = 0
        self.status = "Enter selects a device."
        self.running = True
        self.refresh_nodes()

    def refresh_nodes(self):
        previous_output = self.selected_output.id if self.outputs else None
        previous_input = self.selected_input.id if self.inputs else None
        self.outputs, self.inputs = get_nodes()
        self.output_index = self.find_index(self.outputs, previous_output)
        self.input_index = self.find_index(self.inputs, previous_input)

    @staticmethod
    def find_index(nodes, previous_id):
        if not nodes:
            return 0
        if previous_id is not None:
            for index, node in enumerate(nodes):
                if node.id == previous_id:
                    return index
        for index, node in enumerate(nodes):
            if node.default:
                return index
        return 0

    @property
    def selected_output(self):
        return self.outputs[self.output_index] if self.outputs else None

    @property
    def selected_input(self):
        return self.inputs[self.input_index] if self.inputs else None

    def add(self, y, x, text, style=0):
        height, width = self.screen.getmaxyx()
        if y < 0 or y >= height or x < 0 or x >= width:
            return
        try:
            self.screen.addstr(y, x, clipped(text, width - x), style)
        except curses.error:
            pass

    def draw_box(self, y, x, height, width, title, nodes, selected, focused):
        if height < 3 or width < 5:
            return
        style = curses.color_pair(3) | (curses.A_BOLD if focused else 0)
        self.add(y, x, "+" + "-" * (width - 2) + "+", style)
        for row in range(y + 1, y + height - 1):
            self.add(row, x, "|", style)
            self.add(row, x + width - 1, "|", style)
        self.add(y + height - 1, x, "+" + "-" * (width - 2) + "+", style)
        self.add(y, x + 2, f" {title} ", style | curses.A_BOLD)

        visible = max(0, height - 2)
        start = max(0, selected - visible + 1)
        for row, node in enumerate(nodes[start : start + visible], start=y + 1):
            index = start + row - y - 1
            marker = "(*)" if node.default else "( )"
            label = f" {marker} {node.name}"
            item_style = curses.color_pair(1)
            if focused and index == selected:
                item_style = curses.color_pair(2) | curses.A_BOLD
            self.add(row, x + 1, clipped(label, width - 2).ljust(width - 2), item_style)

        if not nodes:
            self.add(y + 1, x + 2, "No devices found", curses.color_pair(1))

    def draw_button(self, y, x, label, focused):
        style = curses.color_pair(2 if focused else 4) | curses.A_BOLD
        text = f"[ {label} ]"
        self.add(y, x, text, style)
        return len(text)

    def draw(self):
        self.screen.erase()
        height, width = self.screen.getmaxyx()
        self.screen.bkgd(" ", curses.color_pair(1))

        if height < 13 or width < 62:
            self.add(1, 2, "Audio selector needs a 62 x 13 terminal.", curses.A_BOLD)
            self.add(3, 2, "Resize this window, or press q to quit.")
            self.screen.refresh()
            return

        title = " Audio devices "
        self.add(1, max(0, (width - len(title)) // 2), title, curses.A_BOLD | curses.color_pair(3))

        pane_y = 3
        pane_height = height - 9
        gap = 2
        pane_width = (width - gap - 4) // 2
        self.draw_box(pane_y, 2, pane_height, pane_width, "Outputs", self.outputs, self.output_index, self.focus == 0)
        self.draw_box(pane_y, 2 + pane_width + gap, pane_height, pane_width, "Inputs", self.inputs, self.input_index, self.focus == 1)

        buttons = (("Test output", 2), ("Test microphone", 3), ("Quit", 4))
        rendered_width = sum(len(label) + 4 for label, _ in buttons) + 4
        x = max(2, (width - rendered_width) // 2)
        button_y = height - 5
        for label, focus in buttons:
            x += self.draw_button(button_y, x, label, self.focus == focus) + 2

        self.add(height - 3, 2, clipped(self.status, width - 4), curses.color_pair(1))
        help_text = "←/→ section   ↑/↓ device   Enter select/run   r refresh   q quit"
        self.add(height - 1, max(0, (width - len(help_text)) // 2), help_text, curses.color_pair(5))
        self.screen.refresh()

    def select_device(self):
        node = self.selected_output if self.focus == 0 else self.selected_input
        if node is None:
            self.status = "No device is available in this section."
            return
        try:
            run(["wpctl", "set-default", str(node.id)])
            self.status = f"Selected {node.name}."
            self.refresh_nodes()
        except subprocess.CalledProcessError as error:
            self.status = f"Could not select device: {error.stderr.strip()}"

    def with_unmuted(self, nodes, action):
        muted = {node.id: is_muted(node.id) for node in nodes if node is not None}
        try:
            for node_id, was_muted in muted.items():
                if was_muted:
                    set_muted(node_id, False)
            action()
        finally:
            for node_id, was_muted in muted.items():
                if was_muted:
                    set_muted(node_id, True)

    def test_output(self):
        output = self.selected_output
        if output is None:
            self.status = "Choose an output first."
            return
        if not TEST_TRACK.is_file():
            self.status = f"Test track is missing: {TEST_TRACK}"
            return

        self.status = f"Playing 5 seconds on {output.name}…"
        self.draw()
        try:
            with tempfile.TemporaryDirectory(prefix="audio-select-") as temp_dir:
                clip = Path(temp_dir) / "test-output.wav"
                run(
                    [
                        "ffmpeg", "-nostdin", "-loglevel", "error", "-y",
                        "-ss", str(TEST_TRACK_START), "-i", str(TEST_TRACK),
                        "-t", str(TEST_SECONDS), "-vn", "-ac", "2", "-ar", "48000",
                        "-c:a", "pcm_s16le", str(clip),
                    ]
                )
                self.with_unmuted(
                    [output],
                    lambda: run(["pw-play", "--target", str(output.id), str(clip)]),
                )
            self.status = f"Output test finished on {output.name}."
        except subprocess.CalledProcessError as error:
            self.status = f"Output test failed: {error.stderr.strip()}"

    def test_microphone(self):
        source = self.selected_input
        output = self.selected_output
        if source is None or output is None:
            self.status = "Choose both an input and an output first."
            return

        self.status = f"Recording {source.name} for 5 seconds…"
        self.draw()
        try:
            with tempfile.TemporaryDirectory(prefix="audio-select-") as temp_dir:
                recording = Path(temp_dir) / "microphone-test.wav"

                def record():
                    result = run(
                        [
                            "pw-record", "--target", str(source.id),
                            "--rate", "48000", "--channels", "2",
                            "--sample-count", str(TEST_FRAMES), str(recording),
                        ],
                        check=False,
                    )
                    # pw-record 1.6 writes a complete file but returns 1 when it
                    # stops at --sample-count. Validate the recording itself.
                    if not recording.is_file() or recording.stat().st_size <= 44:
                        raise RuntimeError(result.stderr.strip() or "no audio was recorded")

                self.with_unmuted(
                    [source],
                    record,
                )
                self.status = f"Playing the recording on {output.name}…"
                self.draw()
                self.with_unmuted(
                    [output],
                    lambda: run(["pw-play", "--target", str(output.id), str(recording)]),
                )
            self.status = "Microphone test finished."
        except (subprocess.CalledProcessError, RuntimeError) as error:
            detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
            self.status = f"Microphone test failed: {detail}"

    def activate(self):
        if self.focus in (0, 1):
            self.select_device()
        elif self.focus == 2:
            self.test_output()
        elif self.focus == 3:
            self.test_microphone()
        else:
            self.running = False

    def move_vertical(self, delta):
        if self.focus == 0 and self.outputs:
            self.output_index = (self.output_index + delta) % len(self.outputs)
        elif self.focus == 1 and self.inputs:
            self.input_index = (self.input_index + delta) % len(self.inputs)

    def loop(self):
        init_theme()
        self.screen.keypad(True)

        while self.running:
            self.draw()
            key = self.screen.getch()
            if key in (ord("q"), 27):
                self.running = False
            elif key == ord("r"):
                self.refresh_nodes()
                self.status = "Device list refreshed."
            elif key in (curses.KEY_LEFT, curses.KEY_BTAB):
                self.focus = (self.focus - 1) % 5
            elif key in (curses.KEY_RIGHT, 9):
                self.focus = (self.focus + 1) % 5
            elif key == curses.KEY_UP:
                self.move_vertical(-1)
            elif key == curses.KEY_DOWN:
                self.move_vertical(1)
            elif key in (curses.KEY_ENTER, 10, 13, ord(" ")):
                self.activate()


class NetworkSelect(AudioSelect):
    def __init__(self, screen):
        self.screen = screen
        self.wifi = []
        self.vpns = []
        self.wifi_index = 0
        self.vpn_index = 0
        self.focus = 0
        self.status = "Enter connects or toggles the selected item."
        self.running = True
        self.refresh_networks()

    @property
    def selected_wifi(self):
        return self.wifi[self.wifi_index] if self.wifi else None

    @property
    def selected_vpn(self):
        return self.vpns[self.vpn_index] if self.vpns else None

    def refresh_networks(self, *, rescan=False):
        previous_wifi = self.selected_wifi.id if self.wifi else None
        previous_vpn = self.selected_vpn.id if self.vpns else None
        self.wifi, self.vpns = get_networks(rescan=rescan)
        self.wifi_index = self.find_index(self.wifi, previous_wifi)
        self.vpn_index = self.find_index(self.vpns, previous_vpn)

    def draw(self):
        self.screen.erase()
        height, width = self.screen.getmaxyx()
        self.screen.bkgd(" ", curses.color_pair(1))

        if height < 13 or width < 72:
            self.add(1, 2, "Network selector needs a 72 x 13 terminal.", curses.A_BOLD)
            self.add(3, 2, "Resize this window, or press q to quit.")
            self.screen.refresh()
            return

        title = " Network connections "
        self.add(1, max(0, (width - len(title)) // 2), title, curses.A_BOLD | curses.color_pair(3))

        pane_y = 3
        pane_height = height - 9
        gap = 2
        pane_width = (width - gap - 4) // 2
        self.draw_box(pane_y, 2, pane_height, pane_width, "Wi-Fi", self.wifi, self.wifi_index, self.focus == 0)
        self.draw_box(pane_y, 2 + pane_width + gap, pane_height, pane_width, "VPNs", self.vpns, self.vpn_index, self.focus == 1)

        buttons = (("Rescan", 2), ("Quit", 3))
        rendered_width = sum(len(label) + 4 for label, _ in buttons) + 2
        x = max(2, (width - rendered_width) // 2)
        button_y = height - 5
        for label, focus in buttons:
            x += self.draw_button(button_y, x, label, self.focus == focus) + 2

        self.add(height - 3, 2, clipped(self.status, width - 4), curses.color_pair(1))
        help_text = "←/→ section   ↑/↓ item   Enter connect/toggle   r rescan   q quit"
        self.add(height - 1, max(0, (width - len(help_text)) // 2), help_text, curses.color_pair(5))
        self.screen.refresh()

    def prompt_password(self, ssid):
        password = []
        curses.curs_set(1)
        try:
            while True:
                height, width = self.screen.getmaxyx()
                prompt = f"Password for {ssid}: " + "•" * len(password)
                self.add(height - 3, 2, " " * max(0, width - 4), curses.color_pair(1))
                self.add(height - 3, 2, clipped(prompt, width - 4), curses.color_pair(1))
                self.screen.move(height - 3, min(width - 2, 2 + len(prompt)))
                self.screen.refresh()
                key = self.screen.get_wch()
                if key in ("\n", "\r"):
                    return "".join(password)
                if key == "\x1b":
                    return None
                if key in (curses.KEY_BACKSPACE, "\b", "\x7f"):
                    if password:
                        password.pop()
                elif isinstance(key, str) and key.isprintable():
                    password.append(key)
        finally:
            curses.curs_set(0)

    def connect_wifi(self):
        network = self.selected_wifi
        if network is None:
            self.status = "No Wi-Fi network is available."
            return
        if network.active:
            self.status = f"Already connected to {network.ssid}."
            return

        self.status = f"Connecting to {network.ssid}…"
        self.draw()
        try:
            if network.profile_uuid:
                run(["nmcli", "--wait", "30", "connection", "up", "uuid", network.profile_uuid])
            elif not network.security or network.security == "--" or "OWE" in network.security:
                run(["nmcli", "--wait", "30", "device", "wifi", "connect", network.ssid])
            elif "802.1X" in network.security:
                self.status = "This enterprise network needs a saved NetworkManager profile."
                return
            else:
                password = self.prompt_password(network.ssid)
                if password is None:
                    self.status = "Connection cancelled."
                    return
                result = run(
                    ["nmcli", "--ask", "--wait", "30", "device", "wifi", "connect", network.ssid],
                    check=False,
                    input_text=password + "\n",
                )
                if result.returncode != 0:
                    raise RuntimeError(result.stderr.strip() or result.stdout.strip())
            self.refresh_networks()
            self.status = f"Connected to {network.ssid}."
        except (subprocess.CalledProcessError, RuntimeError) as error:
            detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
            self.status = f"Could not connect: {detail}"

    def toggle_vpn(self):
        vpn = self.selected_vpn
        if vpn is None:
            self.status = "No VPN profiles are configured."
            return

        action = "Disconnecting" if vpn.active else "Connecting"
        self.status = f"{action} {vpn.profile_name}…"
        self.draw()
        try:
            if vpn.active:
                run(["nmcli", "--wait", "20", "connection", "down", "uuid", vpn.uuid])
                result = "Disconnected"
            else:
                run(["nmcli", "--wait", "30", "connection", "up", "uuid", vpn.uuid])
                result = "Connected"
            self.refresh_networks()
            self.status = f"{result} {vpn.profile_name}."
        except subprocess.CalledProcessError as error:
            self.status = f"VPN change failed: {error.stderr.strip()}"

    def activate(self):
        if self.focus == 0:
            self.connect_wifi()
        elif self.focus == 1:
            self.toggle_vpn()
        elif self.focus == 2:
            self.status = "Scanning for Wi-Fi networks…"
            self.draw()
            try:
                self.refresh_networks(rescan=True)
                self.status = "Wi-Fi scan finished."
            except subprocess.CalledProcessError as error:
                self.status = f"Scan failed: {error.stderr.strip()}"
        else:
            self.running = False

    def move_vertical(self, delta):
        if self.focus == 0 and self.wifi:
            self.wifi_index = (self.wifi_index + delta) % len(self.wifi)
        elif self.focus == 1 and self.vpns:
            self.vpn_index = (self.vpn_index + delta) % len(self.vpns)

    def loop(self):
        init_theme()
        self.screen.keypad(True)

        while self.running:
            self.draw()
            key = self.screen.getch()
            if key in (ord("q"), 27):
                self.running = False
            elif key == ord("r"):
                self.focus = 2
                self.activate()
            elif key in (curses.KEY_LEFT, curses.KEY_BTAB):
                self.focus = (self.focus - 1) % 4
            elif key in (curses.KEY_RIGHT, 9):
                self.focus = (self.focus + 1) % 4
            elif key == curses.KEY_UP:
                self.move_vertical(-1)
            elif key == curses.KEY_DOWN:
                self.move_vertical(1)
            elif key in (curses.KEY_ENTER, 10, 13, ord(" ")):
                self.activate()


class BluetoothSelect(AudioSelect):
    def __init__(self, screen):
        self.screen = screen
        self.devices = []
        self.device_index = 0
        self.focus = 0
        self.powered = False
        self.pending_forget = None
        self.status = "Enter connects or disconnects."
        self.running = True
        self.refresh_devices()

    @property
    def selected_device(self):
        return self.devices[self.device_index] if self.devices else None

    def refresh_devices(self):
        previous = self.selected_device.id if self.devices else None
        self.powered = bluetooth_powered()
        self.devices = get_bluetooth_devices() if self.powered else []
        self.device_index = self.find_index(self.devices, previous)

    def draw(self):
        self.screen.erase()
        height, width = self.screen.getmaxyx()
        self.screen.bkgd(" ", curses.color_pair(1))
        if height < 15 or width < 66:
            self.add(1, 2, "Bluetooth selector needs a 66 x 15 terminal.", curses.A_BOLD)
            self.add(3, 2, "Resize this window, or press q to quit.")
            self.screen.refresh()
            return

        title = " Bluetooth devices "
        self.add(1, max(0, (width - len(title)) // 2), title, curses.A_BOLD | curses.color_pair(3))
        self.draw_box(3, 2, height - 10, width - 4, "Devices", self.devices, self.device_index, self.focus == 0)

        power_label = "Turn off" if self.powered else "Turn on"
        buttons = ((power_label, 1), ("Scan", 2), ("Quit", 3))
        rendered_width = sum(len(label) + 4 for label, _ in buttons) + 4
        x = max(2, (width - rendered_width) // 2)
        for label, focus in buttons:
            x += self.draw_button(height - 5, x, label, self.focus == focus) + 2

        self.add(height - 3, 2, clipped(self.status, width - 4), curses.color_pair(1))
        help_text = "←/→ section  ↑/↓ device  Enter connect  p pair  t trust  x forget  r scan  q quit"
        self.add(height - 1, max(0, (width - len(help_text)) // 2), help_text, curses.color_pair(5))
        self.screen.refresh()

    def run_device_action(self, verb, command, success):
        device = self.selected_device
        if device is None:
            self.status = "No Bluetooth device is selected."
            return
        self.status = f"{verb} {device.alias}..."
        self.draw()
        result = run(command + [device.address], check=False)
        if result.returncode == 0 and "Failed" not in result.stdout:
            self.refresh_devices()
            self.status = f"{success} {device.alias}."
        else:
            self.status = (result.stderr.strip() or result.stdout.strip() or f"Could not {verb.lower()} device.")

    def toggle_connection(self):
        device = self.selected_device
        if device is None:
            self.status = "No Bluetooth device is selected."
        elif device.connected:
            self.run_device_action("Disconnecting", ["bluetoothctl", "disconnect"], "Disconnected")
        elif not device.paired:
            self.status = "Pair this device first with p."
        else:
            self.run_device_action("Connecting", ["bluetoothctl", "connect"], "Connected")

    def pair(self):
        device = self.selected_device
        if device is None:
            self.status = "No Bluetooth device is selected."
        elif device.paired:
            self.status = f"{device.alias} is already paired. Press x twice to forget it."
        else:
            self.run_device_action("Pairing", ["bluetoothctl", "pair"], "Paired")

    def toggle_trust(self):
        device = self.selected_device
        if device is None:
            self.status = "No Bluetooth device is selected."
            return
        command = "untrust" if device.trusted else "trust"
        success = "Untrusted" if device.trusted else "Trusted"
        self.run_device_action(f"{success[:-2]}ing", ["bluetoothctl", command], success)

    def forget(self):
        device = self.selected_device
        if device is None:
            self.status = "No Bluetooth device is selected."
            return
        if self.pending_forget != device.address:
            self.pending_forget = device.address
            self.status = f"Press x again to forget {device.alias}."
            return
        self.pending_forget = None
        self.run_device_action("Forgetting", ["bluetoothctl", "remove"], "Forgot")

    def scan(self):
        if not self.powered:
            self.status = "Turn Bluetooth on before scanning."
            return
        self.status = "Scanning for Bluetooth devices for 5 seconds..."
        self.draw()
        run(["bluetoothctl", "--timeout", "5", "scan", "on"], check=False)
        self.refresh_devices()
        self.status = "Bluetooth scan finished."

    def activate(self):
        if self.focus == 0:
            self.toggle_connection()
        elif self.focus == 1:
            target = "off" if self.powered else "on"
            result = run(["bluetoothctl", "power", target], check=False)
            self.refresh_devices()
            self.status = f"Bluetooth turned {target}." if result.returncode == 0 else result.stderr.strip()
        elif self.focus == 2:
            self.scan()
        else:
            self.running = False

    def loop(self):
        init_theme()
        self.screen.keypad(True)
        while self.running:
            self.draw()
            key = self.screen.getch()
            if key in (ord("q"), 27):
                self.running = False
            elif key == ord("r"):
                self.scan()
            elif key == ord("p"):
                self.pair()
            elif key == ord("t"):
                self.toggle_trust()
            elif key == ord("x"):
                self.forget()
            elif key in (curses.KEY_LEFT, curses.KEY_BTAB):
                self.focus = (self.focus - 1) % 4
            elif key in (curses.KEY_RIGHT, 9):
                self.focus = (self.focus + 1) % 4
            elif key == curses.KEY_UP and self.focus == 0 and self.devices:
                self.device_index = (self.device_index - 1) % len(self.devices)
                self.pending_forget = None
            elif key == curses.KEY_DOWN and self.focus == 0 and self.devices:
                self.device_index = (self.device_index + 1) % len(self.devices)
                self.pending_forget = None
            elif key in (curses.KEY_ENTER, 10, 13, ord(" ")):
                self.activate()


class PowerSelect(AudioSelect):
    def __init__(self, screen):
        self.screen = screen
        self.actions = POWER_ACTIONS
        self.action_index = 0
        self.pending_action = None
        self.status = "Enter chooses an action."
        self.running = True

    def draw(self):
        self.screen.erase()
        height, width = self.screen.getmaxyx()
        self.screen.bkgd(" ", curses.color_pair(1))
        if height < 14 or width < 52:
            self.add(1, 2, "Power selector needs a 52 x 14 terminal.", curses.A_BOLD)
            self.screen.refresh()
            return
        title = " Session and power "
        self.add(1, max(0, (width - len(title)) // 2), title, curses.A_BOLD | curses.color_pair(3))
        self.draw_box(3, 2, height - 8, width - 4, "Actions", self.actions, self.action_index, True)
        self.add(height - 3, 2, clipped(self.status, width - 4), curses.color_pair(1))
        help_text = "↑/↓ move   Enter choose/confirm   Esc/q cancel"
        self.add(height - 1, max(0, (width - len(help_text)) // 2), help_text, curses.color_pair(5))
        self.screen.refresh()

    def activate(self):
        action = self.actions[self.action_index]
        if action.confirm and self.pending_action != action.id:
            self.pending_action = action.id
            self.status = f"Press Enter again to {action.name.lower()}."
            return
        self.running = False
        curses.endwin()
        subprocess.Popen(action.command, stdin=subprocess.DEVNULL, start_new_session=True)

    def loop(self):
        init_theme()
        self.screen.keypad(True)
        while self.running:
            self.draw()
            key = self.screen.getch()
            if key in (ord("q"), 27):
                if self.pending_action:
                    self.pending_action = None
                    self.status = "Power action cancelled."
                else:
                    self.running = False
            elif key == curses.KEY_UP:
                self.action_index = (self.action_index - 1) % len(self.actions)
                self.pending_action = None
            elif key == curses.KEY_DOWN:
                self.action_index = (self.action_index + 1) % len(self.actions)
                self.pending_action = None
            elif key in (curses.KEY_ENTER, 10, 13, ord(" ")):
                self.activate()


def self_test():
    sample = textwrap.dedent(
        """\
        Audio
         ├─ Sinks:
         │  *   61. Built-in Audio Analog Stereo        [vol: 0.48]
         │      81. Easy Effects Sink                   [vol: 1.00]
         ├─ Sources:
         │      62. Built-in Microphone                  [vol: 0.14]
         │  *  101. USB Microphone                      [vol: 1.00]
         └─ Streams:
        Video
        """
    )
    outputs, inputs = parse_status(sample)
    assert outputs == [
        Node(61, "Built-in Audio Analog Stereo", True),
        Node(81, "Easy Effects Sink", False),
    ]
    assert inputs == [
        Node(62, "Built-in Microphone", False),
        Node(101, "USB Microphone", True),
    ]
    assert split_nmcli(r"home\:office:uuid-1:wireguard::yes") == [
        "home:office", "uuid-1", "wireguard", "", "yes",
    ]
    wifi = parse_wifi_rows(
        " :Cafe:42:WPA2\n*:Home:77:WPA2\n :Home:31:WPA2\n",
        {"Home": "uuid-home"},
    )
    assert wifi == [
        WifiNetwork("Home", 77, "WPA2", True, "uuid-home"),
        WifiNetwork("Cafe", 42, "WPA2", False, None),
    ]
    bluetooth = parse_bluetooth_info(
        "AA:BB:CC:DD:EE:FF",
        "Alias: Headphones\nPaired: yes\nTrusted: yes\nConnected: no\nBlocked: no\nBattery Percentage: 0x4b (75)\n",
    )
    assert bluetooth == BluetoothDevice(
        "AA:BB:CC:DD:EE:FF", "Headphones", True, True, False, False, 75,
    )
    print("audio-select self-test passed")


def main():
    parser = argparse.ArgumentParser(description="Select audio, network, Bluetooth, and power controls")
    parser.add_argument(
        "mode", nargs="?", choices=("audio", "network", "bluetooth", "power"), default="audio",
    )
    parser.add_argument("--dump", action="store_true", help="print detected items and exit")
    parser.add_argument("--self-test", action="store_true", help="run parser tests and exit")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return
    if args.dump:
        if args.mode == "audio":
            outputs, inputs = get_nodes()
            groups = (("Outputs", outputs), ("Inputs", inputs))
        elif args.mode == "network":
            wifi, vpns = get_networks()
            groups = (("Wi-Fi", wifi), ("VPNs", vpns))
        elif args.mode == "bluetooth":
            groups = (("Bluetooth", get_bluetooth_devices()),)
        else:
            groups = (("Power", POWER_ACTIONS),)
        for label, nodes in groups:
            print(label)
            for node in nodes:
                print(f"  {'*' if node.default else ' '} {node.id}: {node.name}")
        return

    screen_class = {
        "audio": AudioSelect,
        "network": NetworkSelect,
        "bluetooth": BluetoothSelect,
        "power": PowerSelect,
    }[args.mode]
    curses.wrapper(lambda screen: screen_class(screen).loop())


if __name__ == "__main__":
    main()
