{ config, ... }:
{
  # Enable WireGuard
  networking.wireguard.interfaces = {
    strange = {
      # Determines the IP address and subnet of the client's end of the tunnel interface.
      ips = [ "192.168.99.8/32" ];
      listenPort = 51820; # to match firewall allowedUDPPorts (without this wg uses random port numbers)

      # ── sops secret (requires ./sops.nix). Plaintext fallback below. ──
      privateKeyFile = config.sops.secrets."wireguard-private-key".path;
      # privateKeyFile = "/etc/nixos/artifacts/keys/wireguard/private_key";

      peers = [
        {
          # Public key of the server (not a file path).
          publicKey = "fLSyzuBDLomN37RSqIz1TQNNHLud5HjafYd6xVto8gU=";
          # ── sops secret (requires ./sops.nix). Plaintext fallback below. ──
          presharedKeyFile = config.sops.secrets."wireguard-preshared-key".path;
          # presharedKeyFile = "/etc/nixos/artifacts/keys/wireguard/preshared_key";
          # Or forward only particular subnets
          allowedIPs = [ "192.168.9.0/24" "192.168.99.0/24" "192.168.1.0/24" ];

          # Set this to the server IP and port.
          endpoint = "strange.langhorst.com:51820";

          # Send keepalives every 25 seconds. Important to keep NAT tables alive.
          persistentKeepalive = 25;
        }
      ];

      postUp = ''
        resolvectl dns strange 192.168.1.2
        resolvectl domain strange ~langhorst.com
      '';
      preDown = ''
        resolvectl revert strange
      '';
    };
  };
}
