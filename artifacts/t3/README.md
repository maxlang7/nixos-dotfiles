# T3 settings snapshot

T3 owns the live writable files in `~/.t3/userdata/`. Home Manager seeds
`client-settings.json` and `keybindings.json` only when each file is missing.
Rebuilds do not reset settings. The snapshot comes from the checked-out Nix
configuration, so a new computer needs the repository's latest committed version.
No additional Git fetch happens during activation.

Waybar rebuilds automatically snapshot T3 settings before evaluating the flake.
On Aragorn, `nrs` and `nrsu` open that same rebuild popup. Nightly automatic
upgrades also snapshot settings first, running the export as the desktop user.
These changes require activation, except for the directly referenced Waybar script.
Missing live settings are skipped on a new machine; malformed settings stop the
rebuild rather than silently shipping a stale snapshot.

You can also snapshot manually:

```sh
t3-settings-sync
git -C /etc/nixos diff -- artifacts/t3
```

For a checkout elsewhere, use `t3-settings-sync --repo /path/to/nixos-dotfiles`.
Review, commit, and push the snapshots manually. The sync command never stages, commits, pushes,
pulls, or deletes files. It can also be run before activation:

```sh
python /etc/nixos/artifacts/scripts/t3-settings-sync.py sync
```

`client-settings-keys.json` explicitly lists exported preferences. New T3
preferences require review before adding them here. This repository is public.
Do not add credentials, provider configuration, browser profiles, machine paths,
databases, attachments, or caches. Keybindings export only key/command/when fields.
Custom themes are currently absent and are not exported by this command.

Existing computers keep their local preferences even after a Git pull. To adopt
the snapshot on an existing computer, quit T3, move the two live files to a backup
location, and activate Home Manager again. Do not replace settings while T3 runs.
Direct `nixos-rebuild` commands bypass the snapshot step. Use the Waybar popup,
`nrs`/`nrsu`, or run the sync command first when invoking a rebuild directly.
This is a snapshot-and-restore workflow, not continuous two-way synchronization.
