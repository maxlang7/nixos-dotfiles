{ lib, userApps, ... }:
let
  control = userApps.control;
in
{
  services.swaync = {
    enable = true;
    settings = builtins.fromJSON (builtins.readFile ../../artifacts/swaync/config.json);
    style = ../../artifacts/swaync/style.css;
  };
  # Hyprland starts this unit explicitly: this session does not start
  # graphical-session.target. Keep D-Bus activation pointing at the same unit.
  systemd.user.services.swaync = {
    Service.ExecStart = lib.mkForce "${control}/bin/notification-control start";
    Install.WantedBy = lib.mkForce [ ];
  };
}
