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


def run(command, *, check=True):
    return subprocess.run(
        command,
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


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
    print("audio-select self-test passed")


def main():
    parser = argparse.ArgumentParser(description="Select and test PipeWire audio devices")
    parser.add_argument("--dump", action="store_true", help="print detected devices and exit")
    parser.add_argument("--self-test", action="store_true", help="run parser tests and exit")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return
    if args.dump:
        outputs, inputs = get_nodes()
        for label, nodes in (("Outputs", outputs), ("Inputs", inputs)):
            print(label)
            for node in nodes:
                print(f"  {'*' if node.default else ' '} {node.id}: {node.name}")
        return

    curses.wrapper(lambda screen: AudioSelect(screen).loop())


if __name__ == "__main__":
    main()
