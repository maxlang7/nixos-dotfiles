"""Translate Codex-only shortcuts into native presets, preserving composer drafts."""
import errno
import fcntl
import json
import os
import pty
import re
import select
import signal
import sys
import termios
import tty

PRESETS = {
    '7': ('Luna medium', '/model gpt-6-luna --reasoning=medium'),
    '8': ('Sol 6.1 low', '/model gpt-6.1-sol --reasoning=low'),
    '5': ('Clear conversation', '/clear'),
    '6': ('Terra 6.1 low', '/model gpt-6.1-terra --reasoning=low'),
    '9': ('Toggle fast mode', '/fast'),
    **{str(i): (effort, '/model --reasoning=' + effort)
       for i, effort in enumerate(('low', 'medium', 'high', 'xhigh'), 1)},
}
SLOTS = {'c': '5', 'f': '9', 'l': '7', 's': '8', 't': '6', **{str(i): str(i) for i in range(1, 5)}}
# Dedicated internal chord, followed by the native preset slot.
MENU = b'\x1b[112;7u'  # Ctrl+Alt+P using CSI-u.


class Translator:
    def __init__(self):
        self.pending = b''
        self.paste = False

    def feed(self, data, flush=False):
        self.pending += data
        output = bytearray()
        while self.pending:
            if self.pending.startswith(b'\x1b[200~'):
                self.paste = True
                output += self.pending[:6]
                self.pending = self.pending[6:]
                continue
            if self.pending.startswith(b'\x1b[201~'):
                self.paste = False
                output += self.pending[:6]
                self.pending = self.pending[6:]
                continue
            if self.pending.startswith(b'\x1b'):
                if not flush and (len(self.pending) == 1 or
                    self.pending.startswith(b'\x1b[') and not re.search(rb'[A-Za-z~]', self.pending[2:])):
                    break
                match = re.match(rb'\x1b\[(\d+);(\d+)(?::([123]))?u', self.pending)
                if match:
                    code, modifiers = int(match[1]), int(match[2])
                    key = chr(code).lower() if code < 128 else ''
                    if not self.paste and modifiers == 3 and key in SLOTS:
                        if match[3] in (None, b'1'):
                            output += MENU + SLOTS[key].encode()
                    else:
                        output += match[0]
                    self.pending = self.pending[match.end():]
                    continue
                if len(self.pending) >= 2 and self.pending[1:2].decode('ascii', 'ignore').lower() in SLOTS and not self.paste:
                    key = self.pending[1:2].decode().lower()
                    output += MENU + SLOTS[key].encode()
                    self.pending = self.pending[2:]
                    continue
            output += self.pending[:1]
            self.pending = self.pending[1:]
        return bytes(output)


def main():
    binary, *args = sys.argv[1:]
    # Subcommands, redirected commands, help and completions use the real CLI directly.
    interactive = sys.stdin.isatty() and sys.stdout.isatty()
    subcommands = {'agents', 'exec', 'e', 'review', 'login', 'logout', 'mcp',
                   'plugin', 'app-server', 'remote-control', 'completion', 'update',
                   'doctor', 'sandbox', 'debug', 'apply', 'a', 'queue', 'archive',
                   'delete', 'migrate-rollouts', 'migrate-nfs-db', 'unarchive',
                   'cloud', 'exec-server', 'features', 'help'}
    skip_value = False
    for arg in args:
        if skip_value:
            skip_value = False
            continue
        if arg in ('-c', '--config', '-m', '--model', '-p', '--profile', '-C', '--cd',
                   '--enable', '--disable', '--remote', '--remote-auth-token-env'):
            skip_value = True
            continue
        if arg in ('--help', '-h', '--version', '-V') or arg in subcommands:
            interactive = False
            break
        if not arg.startswith('-'):
            break
    if not interactive:
        os.execv(binary, [binary, *args])
    config = ['-c', 'tui.keymap.chat.open_presets=["ctrl-alt-p"]']
    for slot, (label, command) in PRESETS.items():
        config += ['-c', f'tui.presets.{slot}.label={json.dumps(label)}',
                   '-c', f'tui.presets.{slot}.input={json.dumps(command)}']
    original = termios.tcgetattr(0)
    pid, master = pty.fork()
    if pid == 0:
        os.execv(binary, [binary, *config, *args])

    def resize(*_):
        try:
            size = fcntl.ioctl(0, termios.TIOCGWINSZ, b'\0' * 8)
            fcntl.ioctl(master, termios.TIOCSWINSZ, size)
        except OSError:
            pass

    translator = Translator()
    resize()
    signal.signal(signal.SIGWINCH, resize)
    try:
        tty.setraw(0)
        while True:
            ready, _, _ = select.select([0, master], [], [], 0.03 if translator.pending else None)
            if not ready:
                os.write(master, translator.feed(b'', flush=True))
            if 0 in ready:
                data = os.read(0, 65536)
                if not data:
                    break
                translated = translator.feed(data)
                if translated:
                    os.write(master, translated)
            if master in ready:
                try:
                    data = os.read(master, 65536)
                except OSError as exc:
                    if exc.errno == errno.EIO:
                        break
                    raise
                if not data:
                    break
                os.write(1, data)
    finally:
        termios.tcsetattr(0, termios.TCSADRAIN, original)
        os.close(master)
    _, status = os.waitpid(pid, 0)
    return os.waitstatus_to_exitcode(status)


if __name__ == '__main__':
    sys.exit(main())
