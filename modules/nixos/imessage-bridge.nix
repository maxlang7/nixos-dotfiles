# ════════════════════════════════════════════════════════════════════════════
#  iMessage → Beeper bridge  (bbctl + mautrix-imessage, via BlueBubbles)
# ────────────────────────────────────────────────────────────────────────────
#  Architecture:
#     iMessage ⇄ BlueBubbles Server (always-on M1 Mac) ⇄ [this service:
#     bbctl + mautrix-imessage] ⇄ your Beeper account ⇄ Beeper Desktop + MCP
#
#  The Mac only runs BlueBubbles Server. This service (on Aragorn) connects OUT
#  to it and relays into Beeper, so iMessage shows up on every Beeper client.
#
#  Reachability: `bluebubblesUrl` is the Mac's home-LAN address. On the LAN we
#  reach it directly; off-LAN it is routed via the `strange` WireGuard tunnel
#  (see wireguard.nix — allowedIPs includes 192.168.1.0/24).
#
#  One-time imperative prerequisite (per-user, NOT declarative):
#     bbctl login          # stores Beeper credentials under ~/.config/bbctl
#  bbctl also downloads the mautrix-imessage binary into ~/.local/share/bbctl
#  at first run. That runtime state lives in $HOME by design.
#
#  Secret: the BlueBubbles server password comes from sops (bluebubbles-password)
#  via the EnvironmentFile below — never written to the nix store or git.
# ════════════════════════════════════════════════════════════════════════════
{ pkgs, config, user, ... }:
let
  # BlueBubbles server on the Mac (home LAN / via WireGuard when away).
  bluebubblesUrl = "http://192.168.1.149:1234";

  bbctl = "${pkgs.beeper-bridge-manager}/bin/bbctl";

  # ExecStart wrapper: $BB_PASSWORD is expanded at RUNTIME from the sops
  # EnvironmentFile, so the store only ever contains the literal "$BB_PASSWORD".
  # (The value is briefly visible in `ps` on this single-user host — acceptable;
  #  it never touches the nix store or git.)
  startScript = pkgs.writeShellScript "imessage-bridge-start" ''
    exec ${bbctl} run \
      --param 'bluebubbles_url=${bluebubblesUrl}' \
      --param "bluebubbles_password=$BB_PASSWORD" \
      --param 'imessage_platform=bluebubbles' \
      sh-imessage
  '';
in
{
  systemd.services.imessage-bridge = {
    description = "iMessage → Beeper bridge (bbctl / mautrix-imessage via BlueBubbles)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    # Don't let systemd give up after repeated failures while off-LAN / Mac asleep.
    startLimitIntervalSec = 0;

    serviceConfig = {
      Type = "simple";
      User = user;
      WorkingDirectory = "/home/${user}";
      Environment = [
        "HOME=/home/${user}"
        # Go needs an explicit CA bundle under systemd's minimal env (TLS to
        # beeper.com + mau.dev).
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      ];

      # ┌─ sops secret (requires ./sops.nix) ──────────────────────────────────┐
      # │ Provides BB_PASSWORD. To revert to plaintext, drop this line and put  │
      # │ the password directly in startScript (NOT recommended).               │
      EnvironmentFile = config.sops.templates."imessage-bridge.env".path;
      # └──────────────────────────────────────────────────────────────────────┘

      ExecStart = startScript;
      Restart = "always";
      RestartSec = 30;
    };
  };
}
