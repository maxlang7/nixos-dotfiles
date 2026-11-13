# Subatomic's profile is portable; the credential is decrypted only at runtime.
{ config, ... }:
{
  sops.secrets."subatomic-psk" = {
    sopsFile = ../../artifacts/sops/secrets/wifi.yaml;
    key = "subatomic-psk";
    mode = "0400";
    restartUnits = [ "NetworkManager-ensure-profiles.service" ];
  };

  sops.templates."wifi-subatomic.env" = {
    mode = "0400";
    content = ''
      SUBATOMIC_PSK=${config.sops.placeholder."subatomic-psk"}
    '';
  };

  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.sops.templates."wifi-subatomic.env".path ];
    profiles.subatomic = {
      connection = {
        id = "subatomic";
        uuid = "883a0162-7c64-4286-9552-74824c1f7cf2";
        type = "wifi";
        autoconnect = true;
      };
      wifi = {
        ssid = "subatomic";
        mode = "infrastructure";
      };
      wifi-security = {
        key-mgmt = "wpa-psk";
        psk = "$SUBATOMIC_PSK";
        psk-flags = 0;
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };
}
