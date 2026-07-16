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
  bluebubblesHost = "192.168.1.149";
  bluebubblesPort = "1234";
  bluebubblesUrl = "http://${bluebubblesHost}:${bluebubblesPort}";

  bbctl = "${pkgs.beeper-bridge-manager}/bin/bbctl";

  # ── self-heal watchdog ─────────────────────────────────────────────────────
  # Failure mode: when the Mac sleeps (lid closed / network blip), the bridge's
  # long-lived socket.io connection to BlueBubbles drops. The bridge PROCESS
  # stays alive (so Restart=always never fires), but sometimes never re-opens
  # the socket after the Mac returns — chats look alive (periodic REST syncs)
  # yet new iMessages silently stop arriving.
  #
  # Detection: BlueBubbles reachable (any HTTP status, incl 401 = Mac awake &
  # serving) BUT no ESTABLISHED TCP socket from us to it = wedged → restart.
  # If BlueBubbles is unreachable (Mac asleep/off-net) we do nothing — a
  # restart wouldn't help and it'll reconnect once the Mac is back.
  watchdogScript = pkgs.writeShellScript "imessage-bridge-watchdog" ''
    set -u
    host=${bluebubblesHost}
    port=${bluebubblesPort}

    # Don't judge a bridge that isn't running or just (re)started — give a
    # fresh start ~90s to establish its socket before we consider it wedged.
    if ! ${pkgs.systemd}/bin/systemctl is-active --quiet imessage-bridge; then
      echo "imessage-bridge not active; leaving it to systemd."
      exit 0
    fi
    active_us=$(${pkgs.systemd}/bin/systemctl show -p ActiveEnterTimestampMonotonic --value imessage-bridge)
    now_us=$(( $(${pkgs.coreutils}/bin/cut -d. -f1 /proc/uptime) * 1000000 ))
    if [ "''${active_us:-0}" -gt 0 ] && [ $(( now_us - active_us )) -lt 90000000 ]; then
      echo "Bridge (re)started <90s ago; letting it settle."
      exit 0
    fi

    # 1. Reachability: code 000 / empty = no HTTP response (Mac asleep/off-net).
    code=$(${pkgs.curl}/bin/curl -s -m 8 -o /dev/null -w '%{http_code}' \
             "http://$host:$port/api/v1/ping" || true)
    if [ -z "$code" ] || [ "$code" = "000" ]; then
      echo "BlueBubbles unreachable (code=''${code:-none}); Mac asleep/off-net — nothing to do."
      exit 0
    fi

    # 2. Reachable — is there a live socket? Retry a few times to ride out a
    #    normal mid-reconnect gap and avoid a spurious restart.
    established() {
      [ -n "$(${pkgs.iproute2}/bin/ss -tnH state established "dst $host:$port")" ]
    }
    for i in 1 2 3; do
      if established; then
        echo "Healthy: BlueBubbles reachable (HTTP $code) and socket established."
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 2
    done

    # 3. Reachable but no socket after retries = wedged. Bounce the bridge.
    echo "WEDGED: BlueBubbles reachable (HTTP $code) but no established socket. Restarting imessage-bridge."
    ${pkgs.systemd}/bin/systemctl restart imessage-bridge
  '';

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

  # ── watchdog: restart the bridge if its BlueBubbles socket wedges ───────────
  # (Runs as root — the default — so it can `systemctl restart` the bridge.)
  systemd.services.imessage-bridge-watchdog = {
    description = "Self-heal the iMessage bridge when its BlueBubbles socket wedges";
    after = [ "imessage-bridge.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = watchdogScript;
    };
  };

  systemd.timers.imessage-bridge-watchdog = {
    description = "Periodic health check for the iMessage bridge";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitActiveSec = "2min";
      AccuracySec = "30s";
    };
  };
}
