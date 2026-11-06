"""Snapshot selected T3 preferences, or seed missing writable settings files."""

import argparse
import json
import os
from pathlib import Path
import tempfile


def read_json(path):
    return json.loads(path.read_text())


def selected_files(source, keys):
    result = {}
    client = source / "client-settings.json"
    if client.exists():
        data = read_json(client)
        if not isinstance(data, dict):
            raise ValueError("client-settings.json must be an object")
        result[client.name] = {key: data[key] for key in keys if key in data}
    bindings = source / "keybindings.json"
    if bindings.exists():
        data = read_json(bindings)
        if not isinstance(data, list) or any(
            not isinstance(item, dict)
            or not {"key", "command"} <= item.keys()
            or not item.keys() <= {"key", "command", "when"}
            or not all(isinstance(value, str) for value in item.values())
            for item in data
        ):
            raise ValueError("Unexpected keybindings format; inspect before exporting")
        result[bindings.name] = data
    return result


def write_json(path, data, seed):
    content = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    if path.is_symlink():
        if seed:
            return
        raise ValueError(f"Refusing to overwrite a symlink: {path}")
    if seed:
        try:
            with path.open("x") as output:
                output.write(content)
        except FileExistsError:
            return
    else:
        if path.exists() and path.read_text() == content:
            return
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as output:
            temporary = Path(output.name)
            try:
                output.write(content)
                output.flush()
                os.replace(temporary, path)
            finally:
                temporary.unlink(missing_ok=True)
    print(f"{'Seeded' if seed else 'Updated'} {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["sync", "seed"])
    parser.add_argument("--repo", type=Path, default=Path("/etc/nixos"))
    parser.add_argument("--snapshot", type=Path, help="Override the snapshot directory")
    parser.add_argument("--userdata", type=Path, default=Path.home() / ".t3/userdata")
    parser.add_argument("--if-present", action="store_true",
                        help="Skip when T3 has no settings yet, for first-time rebuilds")
    args = parser.parse_args()
    snapshot = args.snapshot or args.repo / "artifacts/t3"
    keys = read_json(snapshot / "client-settings-keys.json")
    seed = args.action == "seed"
    source, destination = (snapshot, args.userdata) if seed else (args.userdata, snapshot)
    # Read and validate everything before writing anything. Missing source files
    # never remove snapshots or live settings.
    files = selected_files(source, keys)
    if not files:
        if args.if_present:
            print(f"No T3 settings in {source}; keeping the existing snapshot.")
            return
        parser.error(f"No settings files found in {source}")
    destination.mkdir(parents=True, exist_ok=True)
    for name, data in files.items():
        write_json(destination / name, data, seed)
    if not seed:
        print("Snapshot ready. Review git diff, then commit and push manually.")


if __name__ == "__main__":
    main()
