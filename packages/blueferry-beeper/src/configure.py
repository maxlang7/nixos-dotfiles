"""Render runtime config without putting Beeper credentials in the Nix store."""
import copy
import hashlib
import json
import os
import stat
import sys
import tempfile
from pathlib import Path

import yaml


def private_file(path):
    path = Path(path)
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise ValueError("credential input must be an owner-only regular file")
    return path


def merge(target, source):
    for key, value in source.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            merge(target[key], value)
        else:
            target[key] = copy.deepcopy(value)
    return target


def render(example, credentials, home, poll_seconds=15):
    cfg = merge(copy.deepcopy(example), credentials)
    permissions = credentials["bridge"]["permissions"]
    owners = [key for key, level in permissions.items() if level == "admin" and key.startswith("@")]
    if len(owners) != 1 or len(permissions) != 1:
        raise ValueError("Beeper credentials must specify exactly one bridge owner")
    network = credentials.get("network", {})
    if not network.get("account_id"):
        raise ValueError("credentials require a persistent BlueFerry account binding")
    cfg["network"] = {
        "owner": owners[0], "account_id": network["account_id"],
        "device_env": str(home / ".config/blueferry/local.env"),
        "poll_seconds": poll_seconds,
    }
    cfg["database"].update(type="sqlite3-fk-wal", uri="file:" + str(home / ".local/state/blueferry-beeper/bridge.db") + "?_txlock=immediate")
    cfg["bridge"].update(command_prefix="!bf", async_events=False, split_portals=True, deduplicate_matrix_messages=True)
    cfg["bridge"]["relay"]["enabled"] = False
    cfg["encryption"].update(allow=True, default=True, require=True)
    cfg["appservice"]["hostname"] = "127.0.0.1"
    cfg["appservice"]["bot"]["displayname"] = "BlueFerry"
    if cfg["appservice"]["bot"].get("avatar") is None:
        cfg["appservice"]["bot"]["avatar"] = ""
    cfg["logging"] = {"min_level": "warn", "writers": [{"type": "stdout", "format": "json"}]}
    return cfg


def main():
    os.umask(0o077)
    example_path, credentials_path, output_path = map(Path, sys.argv[1:4])
    home = Path.home()
    credentials = yaml.safe_load(private_file(credentials_path).read_text())
    cfg = render(yaml.safe_load(example_path.read_text()), credentials, home)
    # A phone replacement requires an explicit separate bridge account.
    env = private_file(home / ".config/blueferry/local.env").read_text().splitlines()
    mac = next(line.split("=", 1)[1].strip().upper() for line in env if line.startswith("BLUEFERRY_MAC="))
    binding = "bf-" + hashlib.sha256(mac.encode()).hexdigest()[:32]
    if cfg["network"]["account_id"] != binding:
        raise ValueError("BlueFerry phone changed; refusing to reuse the existing Beeper account")
    output_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    (home / ".local/state/blueferry-beeper").mkdir(mode=0o700, parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(dir=output_path.parent, prefix="config.")
    try:
        with os.fdopen(descriptor, "w") as stream:
            yaml.safe_dump(cfg, stream, sort_keys=False)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, output_path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        raise SystemExit("BlueFerry bridge configuration failed; check private credentials and device binding")
