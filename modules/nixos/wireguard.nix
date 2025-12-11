{...}:
{
  networking.firewall = {
    allowedUDPPorts = [ 51820 ]; # Clients and peers can use the same port, see listenport
  };
  # Enable WireGuard
  # networking.wireguard.interfaces = {
  #   seltsam = {
  #     # Determines the IP address and subnet of the client's end of the tunnel interface.
  #     ips = [ "192.168.99.8/32" ];
  #     listenPort = 51820; # to match firewall allowedUDPPorts (without this wg uses random port numbers)

  #     privateKeyFile = "/etc/nixos/artifacts/keys/wireguard/private_key";

  #     peers = [
  #       {
  #         # Public key of the server (not a file path).
  #         publicKey = "fLSyzuBDLomN37RSqIz1TQNNHLud5HjafYd6xVto8gU=";
  #         presharedKeyFile = "/etc/nixos/artifacts/keys/wireguard/preshared_key";
  #         # Or forward only particular subnets
  #         allowedIPs = [ "192.168.9.0/24" "192.168.99.0/24" "192.168.1.0/24" ];

  #         # Set this to the server IP and port.
  #         endpoint = "seltsam.langhorst.com:51820";

  #         # Send keepalives every 25 seconds. Important to keep NAT tables alive.
  #         persistentKeepalive = 25;
  #       }
  #     ];
  #   };
};
}