# BlueFerry to Beeper

A local Matrix bridge for BlueFerry's version 2 session D-Bus API. The maintained
mautrix-go bridgev2 framework handles Matrix, encryption, persistent portals,
message deduplication and Beeper's outbound appservice websocket. It uses Go's
Olm implementation and does not depend on libolm.

BlueFerry reads your paired iPhone over Bluetooth. This connector imports its
retained text conversations into a separate `sh-blueferry` Beeper registration.
It exposes cached contacts, names and available photos. Plain text sent from an
existing direct conversation calls `SendToThreadChecked`; unsupported media,
quoted replies, edits, reactions, typing and all group sends fail explicitly.
Beeper Desktop labels this custom network “undefined” because its network names
are fixed. The account and chats work using the supported `bridgev2` type.
Changing the registration type to the legacy iMessage bridge hides this account.
BlueFerry retains both iMessage and SMS and cannot distinguish them reliably.

This does not recover an entire iPhone archive. Only the bounded history retained
by BlueFerry is imported. Contacts can be browsed, but a conversation must already
exist in BlueFerry before you can reply to it. Phone read receipts are not changed
by the connector. A durable send guard prevents the same Matrix event from being submitted twice,
including after a restart or an uncertain outcome. Do not retry an uncertain send
until you have checked the phone.

## Development

Run `nix-shell` here. The shell creates `.venv` and installs pinned Python test
dependencies. Then run:

```
go build -tags goolm -o blueferry-beeper .
BLUEFERRY_TEST_BUS=1 dbus-run-session -- go test -tags goolm -race ./...
python -m pytest -q test_configure.py
./blueferry-beeper --probe
```

The probe reports only counts and connection status. The D-Bus integration test
requires an isolated bus and uses synthetic contacts and messages. Tests do not
send anything to your phone or real contacts.

## Declarative installation on Aragorn

The authoritative deployed source is committed under
`/etc/nixos/packages/blueferry-beeper/src`. The package pins Go dependencies with
`go.mod`, `go.sum` and a fixed vendor hash. Nix builds the binary and runs the
isolated D-Bus tests. The Home Manager module declares `blueferry-beeper.service`,
its dependencies, sandbox, restart policy and runtime configuration generation.
Only activation starts the persistent service.

Beeper registration is external account state. Its generated credentials are
stored encrypted in `artifacts/sops/secrets/blueferry-beeper.yaml`, decrypted to
an owner-only `/run/secrets/blueferry-beeper-config`, and merged with declared
settings at service start. Tokens never enter the Nix store. The account is bound
to a hash of the BlueFerry phone address. Changing phones requires an explicit new
account; the connector refuses to reuse the old account for another phone.

Private runtime configuration is under `~/.config/blueferry-beeper`. Portal
identities, encryption state, messages and routing aliases are retained in
`~/.local/state/blueferry-beeper/bridge.db`. Restore this directory with its matching
credentials when moving the bridge. Losing the database can duplicate historical
imports and loses encryption/device state. Do not run two instances using the
same registration. A process lock prevents a second local instance from starting.
The former `sh-imessage` registration and data are separate.

For a new Beeper account, authenticate `bbctl`, generate
`bbctl config --type bridgev2 --output PRIVATE_FILE sh-blueferry`, add a
`network.account_id` matching `bf-` plus the first 32 SHA-256 hex characters of
the uppercase phone MAC from BlueFerry's private local.env, and encrypt that
configuration with the repository's SOPS recipient. No credentials belong in
source control in plaintext. Preserve the encrypted credentials and age private
key securely; the private key is deliberately outside the commit.

Validate with `nixos-rebuild dry-build --flake /etc/nixos#Aragorn` before activation.
After explicit approval, Aragorn's Waybar authentication popup is launched with
`/etc/nixos/artifacts/scripts/nixos-rebuild-waybar.sh start`. This also applies the
existing configuration that disables the former Mac/BlueBubbles bridge and its
watchdog while preserving its data.
