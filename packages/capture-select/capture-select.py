#!/usr/bin/env python3

import argparse
import curses
import signal
import subprocess
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


OUTPUT_DIR = Path.home() / "Videos" / "Recordings"


@dataclass(frozen=True)
class AudioDevice:
    name: str
    description: str


@dataclass(frozen=True)
class Row:
    kind: str
    key: str
    label: str
    selectable: bool = True


def run(command, *, check=True):
    return subprocess.run(
        command,
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def parse_pipe_list(output):
    items = []
    for line in output.splitlines():
        name, separator, description = line.partition("|")
        if name:
            items.append((name, description if separator else name))
    return items


def get_monitors():
    return [AudioDevice(name, description) for name, description in parse_pipe_list(
        run(["gpu-screen-recorder", "--list-monitors"]).stdout
    )]


def get_audio_devices():
    devices = parse_pipe_list(run(["gpu-screen-recorder", "--list-audio-devices"]).stdout)
    microphones = []
    for name, description in devices:
        if name == "default_input":
            microphones.append(AudioDevice(name, description))
        elif name != "default_output" and not name.endswith(".monitor"):
            microphones.append(AudioDevice(name, description))
    return microphones


def get_application_audio():
    result = run(["gpu-screen-recorder", "--list-application-audio"], check=False)
    return sorted({line.strip() for line in result.stdout.splitlines() if line.strip()}, key=str.lower)


def init_theme():
    curses.curs_set(0)
    curses.use_default_colors()
    if curses.COLORS >= 256:
        curses.init_pair(1, 248, 234)
        curses.init_pair(2, 214, 235)
        curses.init_pair(3, 223, 234)
        curses.init_pair(4, 142, 234)
        curses.init_pair(5, 172, 234)
        curses.init_pair(6, 167, 234)
        curses.init_pair(7, 175, 234)
    else:
        curses.init_pair(1, curses.COLOR_WHITE, curses.COLOR_BLACK)
        curses.init_pair(2, curses.COLOR_BLACK, curses.COLOR_BLUE)
        curses.init_pair(3, curses.COLOR_MAGENTA, curses.COLOR_BLACK)
        curses.init_pair(4, curses.COLOR_BLACK, curses.COLOR_GREEN)
        curses.init_pair(5, curses.COLOR_WHITE, curses.COLOR_BLACK)
        curses.init_pair(6, curses.COLOR_RED, curses.COLOR_BLACK)
        curses.init_pair(7, curses.COLOR_MAGENTA, curses.COLOR_BLACK)


def clipped(text, width):
    if width <= 0:
        return ""
    if len(text) <= width:
        return text
    if width == 1:
        return text[:1]
    return text[: width - 1] + "…"


def format_duration(seconds):
    minutes, seconds = divmod(max(0, int(seconds)), 60)
    hours, minutes = divmod(minutes, 60)
    if hours:
        return f"{hours}:{minutes:02d}:{seconds:02d}"
    return f"{minutes:02d}:{seconds:02d}"


class CaptureSelect:
    def __init__(self, screen):
        self.screen = screen
        self.monitors = get_monitors()
        self.microphones = get_audio_devices()
        self.applications = get_application_audio()
        self.video_mode = "screen"
        self.monitor = self.monitors[0].name if self.monitors else "screen"
        self.microphone = None
        self.all_output = False
        self.selected_apps = set()
        self.rows = []
        self.index = 0
        self.scroll = 0
        self.status = "Space changes a choice. Enter starts recording."
        self.process = None
        self.log_handle = None
        self.started_at = None
        self.output_path = None
        self.last_error = ""
        self.running = True
        self.rebuild_rows()

    def rebuild_rows(self):
        selected_key = self.rows[self.index].key if self.rows and self.index < len(self.rows) else None
        rows = [
            Row("header", "video-header", "Video", False),
            Row("video", "screen", f"Full screen: {self.monitor}"),
            Row("video", "portal", "Browser/window: choose through portal"),
            Row("header", "mic-header", "Microphone", False),
            Row("microphone", "none", "None"),
        ]
        rows.extend(Row("microphone", device.name, device.description) for device in self.microphones)
        rows.extend([
            Row("header", "audio-header", "System audio", False),
            Row("output", "default_output", "Everything on the current output"),
        ])
        if self.applications:
            rows.extend(Row("application", app, f"Application: {app}") for app in self.applications)
        else:
            rows.append(Row("empty", "no-apps", "No applications are playing audio", False))
        rows.extend([
            Row("header", "action-header", "Recording", False),
            Row("action", "record", "Start recording"),
            Row("action", "refresh", "Refresh audio applications"),
            Row("action", "quit", "Quit"),
        ])
        self.rows = rows
        if selected_key:
            for index, row in enumerate(rows):
                if row.key == selected_key:
                    self.index = index
                    break
        self.index = min(self.index, len(rows) - 1)
        self.ensure_selectable(1)

    def ensure_selectable(self, direction):
        if not self.rows:
            return
        for _ in self.rows:
            if self.rows[self.index].selectable:
                return
            self.index = (self.index + direction) % len(self.rows)

    def add(self, y, x, text, style=0):
        height, width = self.screen.getmaxyx()
        if y < 0 or y >= height or x < 0 or x >= width:
            return
        try:
            self.screen.addstr(y, x, clipped(text, width - x), style)
        except curses.error:
            pass

    def row_marker(self, row):
        if row.kind == "video":
            return "●" if self.video_mode == row.key else "○"
        if row.kind == "microphone":
            selected = (row.key == "none" and self.microphone is None) or row.key == self.microphone
            return "●" if selected else "○"
        if row.kind == "output":
            return "●" if self.all_output else "○"
        if row.kind == "application":
            return "●" if row.key in self.selected_apps else "○"
        if row.kind == "action":
            return "›"
        return " "

    def draw(self):
        self.screen.erase()
        height, width = self.screen.getmaxyx()
        self.screen.bkgd(" ", curses.color_pair(1))

        if height < 16 or width < 72:
            self.add(1, 2, "Capture selector needs a 72 x 16 terminal.", curses.A_BOLD)
            self.add(3, 2, "Resize this window, or press q to quit.")
            self.screen.refresh()
            return

        title = " Screen recorder "
        self.add(1, max(0, (width - len(title)) // 2), title, curses.A_BOLD | curses.color_pair(7))
        border_width = width - 4
        top = 3
        bottom = height - 5
        self.add(top, 2, "╭" + "─" * (border_width - 2) + "╮", curses.color_pair(1))
        for y in range(top + 1, bottom):
            self.add(y, 2, "│", curses.color_pair(1))
            self.add(y, width - 3, "│", curses.color_pair(1))
        self.add(bottom, 2, "╰" + "─" * (border_width - 2) + "╯", curses.color_pair(1))

        visible = bottom - top - 1
        if self.index < self.scroll:
            self.scroll = self.index
        if self.index >= self.scroll + visible:
            self.scroll = self.index - visible + 1

        for y, row in enumerate(self.rows[self.scroll : self.scroll + visible], start=top + 1):
            actual_index = self.scroll + y - top - 1
            if row.kind == "header":
                text = f" {row.label} "
                self.add(y, 4, text, curses.color_pair(3) | curses.A_BOLD)
                continue
            marker = self.row_marker(row)
            text = f" {marker} {row.label}"
            style = curses.color_pair(1)
            if marker == "●":
                style = curses.color_pair(4)
            if actual_index == self.index and not self.process:
                style = curses.color_pair(2) | curses.A_BOLD
            self.add(y, 3, clipped(text, width - 6).ljust(width - 6), style)

        if self.process:
            elapsed = format_duration(time.monotonic() - self.started_at)
            state = f"RECORDING  {elapsed}  Enter stops and saves"
            self.add(height - 3, max(2, (width - len(state)) // 2), state, curses.color_pair(6) | curses.A_BOLD)
        else:
            self.add(height - 3, 2, clipped(self.status, width - 4), curses.color_pair(1))
        help_text = "↑/↓ move   Space change   Enter start/stop   r refresh   q quit"
        self.add(height - 1, max(0, (width - len(help_text)) // 2), help_text, curses.color_pair(5))
        self.screen.refresh()

    def move(self, direction):
        if self.process:
            return
        for _ in self.rows:
            self.index = (self.index + direction) % len(self.rows)
            if self.rows[self.index].selectable:
                break

    def toggle(self):
        if self.process:
            return
        row = self.rows[self.index]
        if row.kind == "video":
            self.video_mode = row.key
            self.status = "The portal can select a window, not an individual browser tab."
        elif row.kind == "microphone":
            self.microphone = None if row.key == "none" else row.key
        elif row.kind == "output":
            self.all_output = not self.all_output
            if self.all_output:
                self.selected_apps.clear()
        elif row.kind == "application":
            self.all_output = False
            if row.key in self.selected_apps:
                self.selected_apps.remove(row.key)
            else:
                self.selected_apps.add(row.key)
        elif row.kind == "action":
            self.activate()

    def refresh_applications(self):
        try:
            self.applications = get_application_audio()
            self.selected_apps.intersection_update(self.applications)
            self.rebuild_rows()
            self.status = "Application audio list refreshed."
        except subprocess.CalledProcessError as error:
            self.status = f"Refresh failed: {error.stderr.strip()}"

    def next_output_path(self):
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        candidate = OUTPUT_DIR / f"recording_{stamp}.mkv"
        counter = 2
        while candidate.exists():
            candidate = OUTPUT_DIR / f"recording_{stamp}_{counter}.mkv"
            counter += 1
        return candidate

    def build_command(self, output_path):
        capture = self.monitor if self.video_mode == "screen" else "portal"
        command = [
            "gpu-screen-recorder",
            "-w", capture,
            "-f", "60",
            "-k", "h264",
            "-q", "high",
            "-fm", "cfr",
            "-cursor", "yes",
        ]
        audio_sources = []
        if self.microphone:
            audio_sources.append(f"device:{self.microphone}")
        if self.all_output:
            audio_sources.append("default_output")
        else:
            audio_sources.extend(f"app:{name}" for name in sorted(self.selected_apps, key=str.lower))
        if audio_sources:
            command.extend(["-a", "|".join(audio_sources)])
        command.extend(["-o", str(output_path)])
        return command

    def start_recording(self):
        output_path = self.next_output_path()
        command = self.build_command(output_path)
        log_path = output_path.with_suffix(".log")
        self.log_handle = log_path.open("w", encoding="utf-8")
        try:
            self.process = subprocess.Popen(
                command,
                stdin=subprocess.DEVNULL,
                stdout=self.log_handle,
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )
        except OSError as error:
            self.log_handle.close()
            self.log_handle = None
            self.status = f"Could not start recorder: {error}"
            return
        self.started_at = time.monotonic()
        self.output_path = output_path
        self.last_error = ""

    def finish_process(self):
        return_code = self.process.poll() if self.process else None
        if self.log_handle:
            self.log_handle.close()
            self.log_handle = None
        saved_path = self.output_path
        self.process = None
        self.started_at = None
        self.output_path = None
        if return_code == 0 and saved_path and saved_path.exists():
            mp4_path = saved_path.with_suffix(".mp4")
            log_path = saved_path.with_suffix(".log")
            self.status = f"Converting to {mp4_path.name}..."
            self.draw()
            with log_path.open("a", encoding="utf-8") as conversion_log:
                conversion = subprocess.run(
                    [
                        "ffmpeg", "-y", "-i", str(saved_path),
                        "-map", "0:v:0", "-map", "0:a?",
                        "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
                        "-movflags", "+faststart", str(mp4_path),
                    ],
                    stdin=subprocess.DEVNULL,
                    stdout=conversion_log,
                    stderr=subprocess.STDOUT,
                    check=False,
                )
            if conversion.returncode == 0 and mp4_path.exists():
                self.status = f"Saved {mp4_path}"
            else:
                self.status = f"Saved MKV; MP4 conversion failed. See {log_path}"
        else:
            log_path = saved_path.with_suffix(".log") if saved_path else None
            self.status = f"Recording failed. See {log_path}" if log_path else "Recording failed."

    def stop_recording(self):
        if not self.process:
            return
        self.process.send_signal(signal.SIGINT)
        try:
            self.process.wait(timeout=20)
        except subprocess.TimeoutExpired:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.status = "Recorder did not stop. Close it before quitting."
                return
        self.finish_process()

    def activate(self):
        if self.process:
            self.stop_recording()
            return
        row = self.rows[self.index]
        if row.kind != "action":
            self.start_recording()
        elif row.key == "record":
            self.start_recording()
        elif row.key == "refresh":
            self.refresh_applications()
        else:
            self.running = False

    def poll_recorder(self):
        if self.process and self.process.poll() is not None:
            self.finish_process()

    def loop(self):
        init_theme()
        self.screen.keypad(True)
        self.screen.timeout(250)
        while self.running:
            self.poll_recorder()
            self.draw()
            key = self.screen.getch()
            if key == -1:
                continue
            if key in (ord("q"), 27):
                if self.process:
                    self.status = "Stop the recording with Enter before quitting."
                else:
                    self.running = False
            elif key == ord("r") and not self.process:
                self.refresh_applications()
            elif key == curses.KEY_UP:
                self.move(-1)
            elif key == curses.KEY_DOWN:
                self.move(1)
            elif key == ord(" "):
                self.toggle()
            elif key in (curses.KEY_ENTER, 10, 13):
                self.activate()


def self_test():
    assert parse_pipe_list("one|First\ntwo|Second\n") == [("one", "First"), ("two", "Second")]
    assert format_duration(0) == "00:00"
    assert format_duration(65) == "01:05"
    assert format_duration(3661) == "1:01:01"
    print("capture-select self-test passed")


def main():
    parser = argparse.ArgumentParser(description="Choose screen and audio sources to record")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--dump", action="store_true", help="print available sources and exit")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if args.dump:
        print("Monitors")
        for monitor in get_monitors():
            print(f"  {monitor.name}: {monitor.description}")
        print("Microphones")
        for microphone in get_audio_devices():
            print(f"  {microphone.name}: {microphone.description}")
        print("Applications")
        for application in get_application_audio():
            print(f"  {application}")
        return
    curses.wrapper(lambda screen: CaptureSelect(screen).loop())


if __name__ == "__main__":
    main()
