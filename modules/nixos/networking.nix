{ pkgs, ... }:
{
  networking.hostName = "Aragorn";
  networking.networkmanager.enable = true;

  # This is the correct way to use `let ... in` within a NixOS module
  # or any attribute set.
  networking.wireless.networks = let
    collegeCaCert = pkgs.writeTextFile {
      name = "cmu.crt";
      text = builtins.readFile ../../artifacts/cmu.crt;
    };
  in
  {
    "Carnegie Mellon" = {
      enable = true;
      connection = {
        id = "Carnegie Mellon";
        uuid = "33ce2b80-8980-4a2a-bf2c-953245977e9c";
        type = "802-11-wireless-security";
      };
      "802-11-wireless" = {
        ssid = "CMU-SECURE";
        mode = "infrastructure";
      };
      "802-11-wireless-security" = {
        key-mgmt = "wpa-eap";
      };
      "802-1x" = {
        eap = "peap";
        identity = "mlanghor@andrew.cmu.edu";
        phase2-auth = "mschapv2";
        ca-cert = collegeCaCert;
        password = "3&zP2o!XUf2@";
      };
    };
  };
}