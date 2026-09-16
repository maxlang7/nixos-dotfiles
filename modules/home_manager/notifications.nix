{ config, lib, pkgs, ... }:
let
  control = pkgs.writeShellApplication {
    name = "notification-control";
    runtimeInputs = [ pkgs.swaynotificationcenter pkgs.jq pkgs.coreutils pkgs.systemd ];
    text = ''
      export NOTIFICATIONS_STYLE=${../../artifacts/swaync/style.css}
      export NOTIFICATIONS_BASE_CONFIG=${config.xdg.configFile."swaync/config.json".source}
    '' + builtins.readFile ../../artifacts/scripts/notification-control.sh;
  };
in
{
  services.swaync = {
    enable = true;
    settings = builtins.fromJSON (builtins.readFile ../../artifacts/swaync/config.json);
    style = ../../artifacts/swaync/style.css;
  };
  home.packages = [ control ];
  # Hyprland starts this unit explicitly: this session does not start
  # graphical-session.target. Keep D-Bus activation pointing at the same unit.
  systemd.user.services.swaync = {
    Service.ExecStart = lib.mkForce "${control}/bin/notification-control start";
    Install.WantedBy = lib.mkForce [ ];
  };
}
