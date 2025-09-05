{pkgs,... }:
{
  networking.hostName = "Aragorn";
  networking.networkmanager.enable = true;
  systemd.services.wifi-time-fix = {
    description = "Temporarily sets time to fix Wi-Fi certificate validation";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.coreutils ];
  
    serviceConfig = {
      User = "root";
      Type = "oneshot"; 
      ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/artifacts/scripts/timeset.sh";
      #FailureAction = "continue";
      # Also, consider a timeout to prevent an infinite stall
      TimeoutSec = "60s"; 
    };
  };
}