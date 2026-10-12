# BlueFerry on Aragorn

`default.nix` pins upstream source and its hash. `recent-inbox.patch` carries
our bounded initial inbox import and regression tests. Runtime commands use
Nix store paths. Neither the service nor GTK launcher depends on a checkout,
virtual environment, nix-shell, or pip.

Configuration is split between `modules/nixos/blueferry.nix` and
`modules/home_manager/blueferry.nix`. Only Aragorn imports them. The system
module provides the restricted Bluetooth class helper and SOPS phone address.
The user module provides the package, service, private runtime configuration,
and plaintext storage initialization. Other settings remain application data.

The config writer reads the phone address from `/run/secrets/blueferry-mac`,
never from an evaluated Nix value. Keep the age decryption key outside Git.
A fresh machine must have that key provisioned for SOPS to decrypt the file.
Bluetooth bonding and the iPhone's permission toggles are device state, not
reproducible configuration. Enable contact sharing and message notifications
for this computer on the iPhone after pairing.

Plaintext storage is deliberate. Startup initializes a fresh settings document
or accepts an existing plaintext policy. It refuses an incompatible policy
instead of clearing contacts or messages automatically. An intentional policy
migration must use BlueFerry's CLI or settings UI and its normal confirmation.

The initial conversation import requests at most 20 inbox summaries when
local message history is empty. It uses the phone's message subjects, which
may be truncated. It does not fetch iCloud history or complete sent history,
does not dispatch notifications or copy historical OTPs, and discards results
if the MAP session or storage generation changed. Existing local history is
preserved. Incoming messages continue through the normal event listener.

Contact photos and OTP autocopy are enabled, with a 60-second clipboard timeout.
Media control is requested but unavailable while ANCS compatibility mode is
selected. Do not assume that setting the option proves the phone supports it.
Changing pairing mode requires a separate pairing operation.

## Validation and upgrades

Run `nixos-rebuild dry-build --flake /etc/nixos#Aragorn` after changes. Build the
package independently to execute its 89 integration and regression tests:

```sh
nix build --impure --expr '(let f = builtins.getFlake "/etc/nixos"; pkgs = import f.inputs.nixpkgs { system = "x86_64-linux"; }; in pkgs.callPackage /etc/nixos/packages/blueferry {})'
```

When upgrading, update the pinned revision and hash, rebase the patch against
that revision, and build again. Package identity incorporates the source and
patch hash so clients detect an older daemon. Run the upstream suite in the
development checkout with `TZDIR=/etc/zoneinfo` and a short pytest `--basetemp`
path. GTK's Unix display sockets cannot fit long nix-shell temporary paths.

The first Home Manager activation recognizes the exact handwritten setup unit
by its SHA-256 and moves it and its enablement link into
`~/.local/state/blueferry-install-backup/`. Unknown edits cause a collision
instead of being overwritten. Application settings, contacts, messages, and
Bluetooth bonds are not moved or deleted. The development checkout and `.venv`
can stay for development and are not runtime dependencies.

Activate only after review, using `/etc/nixos/artifacts/scripts/nixos-rebuild-waybar.sh start`.
This opens the existing authentication popup without updating flake inputs.
After the approved NixOS activation, verify `systemctl --user status
blueferry.service`, run `blueferry doctor`, and confirm conversations in GTK.
Do not equate a dry-build with an activated service.
