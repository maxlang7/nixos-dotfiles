{ pkgs, user, ... }:
let
  blueferrySetCod = pkgs.writeShellApplication {
    name = "blueferry-set-cod";
    runtimeInputs = [ pkgs.bluez ];
    text = ''
      if [ "$#" -ne 1 ]; then
        echo "usage: blueferry-set-cod INDEX" >&2
        exit 64
      fi
      case "$1" in
        ""|*[!0-9]*)
          echo "adapter index must contain only decimal digits" >&2
          exit 64
          ;;
      esac
      : | btmgmt --index "$1" class 4 8
    '';
  };
in
{
  # BlueZ also has its own hands-free profile, independent of WirePlumber.
  # Disable that audio/call service while retaining MAP/PBAP and A2DP source.
  hardware.bluetooth.disabledPlugins = [ "hfp" ];

  # BlueZ's monitor in WirePlumber 0.5 does not honor device.disabled itself.
  # Add the same early exit used by the ALSA monitor, before any audio device
  # is created. Keep this small and fail the build if upstream changes it.
  services.pipewire.wireplumber.configPackages = [
    (pkgs.runCommand "wireplumber-blueferry-no-phone-audio" {
      nativeBuildInputs = [ pkgs.python3 ];
    } ''
      mkdir -p "$out/share/wireplumber/scripts/monitors"
      python ${../../packages/blueferry/disable-phone-audio.py} \
        ${pkgs.wireplumber}/share/wireplumber/scripts/monitors/bluez.lua \
        "$out/share/wireplumber/scripts/monitors/bluez.lua"
    '')
  ];
  services.pipewire.wireplumber.extraConfig."zzzz-blueferry-no-phone-audio" = {
    "monitor.bluez.rules" = [
      {
        matches = [
          { "device.name" = "~bluez_card.*"; "device.icon-name" = "~^(phone|audio-card-phone)(-bluetooth)?$"; }
          { "device.name" = "~bluez_card.*"; "device.form-factor" = "handset"; }
        ];
        actions."update-props" = {
          "device.disabled" = true;
          "bluez5.auto-connect" = [ ];
        };
      }
    ];
  };

  environment.systemPackages = [ blueferrySetCod ];

  # The paired phone address stays encrypted at rest and out of the Nix store.
  sops.secrets."blueferry-mac" = {
    sopsFile = ../../artifacts/sops/secrets/blueferry.yaml;
    format = "yaml";
    key = "blueferry-mac";
    owner = user;
    group = "users";
    mode = "0400";
  };

  # Only the narrowly sandboxed helper can receive this Polkit authorization.
  systemd.services."blueferry-btmgmt-set-class@" = {
    description = "Set Bluetooth adapter hci%i class for BlueFerry";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${blueferrySetCod}/bin/blueferry-set-cod %i";
      NoNewPrivileges = true;
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = [ "AF_BLUETOOTH" ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
    };
  };

  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    // Permit active local sessions to start only BlueFerry's restricted helper.
    polkit.addRule(function(action, subject) {
        if (action.id !== "org.freedesktop.systemd1.manage-units" ||
            action.lookup("verb") !== "start" ||
            !subject.active || !subject.local || subject.user !== "${user}") {
            return polkit.Result.NOT_HANDLED;
        }

        var unit = action.lookup("unit");
        if (unit && /^blueferry-btmgmt-set-class@[0-9]+\.service$/.test(unit)) {
            return polkit.Result.YES;
        }
        return polkit.Result.NOT_HANDLED;
    });
  '';
}
