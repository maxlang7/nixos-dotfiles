{ pkgs, ... }:
let
  bridge = pkgs.callPackage ../../packages/blueferry-beeper { };
  configure = pkgs.writeShellScript "blueferry-beeper-configure" ''
    set -euo pipefail
    umask 077
    exec ${bridge}/bin/blueferry-beeper-configure \
      ${bridge}/share/blueferry-beeper/example.yaml \
      /run/secrets/blueferry-beeper-config \
      "$HOME/.config/blueferry-beeper/config.yaml"
  '';
in
{
  home.packages = [ bridge ];
  systemd.user.services.blueferry-beeper = {
    Unit = {
      Description = "BlueFerry encrypted text bridge to Beeper";
      After = [ "blueferry.service" ];
      Wants = [ "blueferry.service" ];
    };
    Service = {
      Type = "simple";
      ExecStartPre = "${configure}";
      ExecStart = "${bridge}/bin/blueferry-beeper --no-update --config %h/.config/blueferry-beeper/config.yaml";
      WorkingDirectory = "%h/.local/state/blueferry-beeper";
      Restart = "on-failure";
      RestartSec = "15s";
      TimeoutStopSec = "15s";
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [ "%h/.config/blueferry-beeper" "%h/.local/state/blueferry-beeper" ];
      RestrictSUIDSGID = true;
      LockPersonality = true;
      RestrictRealtime = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
    };
    Install.WantedBy = [ "default.target" ];
  };
  home.activation.blueferryBeeperDirectories = {
    after = [ "writeBoundary" ];
    before = [ ];
    data = ''
      run ${pkgs.coreutils}/bin/install -d -m 0700 \
        "$HOME/.config/blueferry-beeper" "$HOME/.local/state/blueferry-beeper"
    '';
  };
}
