{ config, pkgs, ... }:

{
 { config, pkgs, ... }:

let
  # Replace with your root partition's UUID (find via `sudo blkid -s UUID -o value /dev/nvme0n1p2`)
  rootUUID = "c13c896f-2532-44ae-a99d-114d8b67ac83";
  
  # Swap file settings
  swapfileSize = "32G"; # Should match your RAM size
  swapfilePath = "/swap/swapfile";
in {
  # 1. Create swap file declaratively
  systemd.tmpfiles.rules = [
    "f ${swapfilePath} 0600 root root - ${swapfileSize}"
  ];

  # 2. Enable swap file
  swapDevices = [{
    device = swapfilePath;
    # Auto-calculate resume_offset during rebuild
    resumeOffset = let
      offsetScript = pkgs.writeScript "get-offset" ''
        ${pkgs.e2fsprogs}/bin/filefrag -v ${swapfilePath} | \
        ${pkgs.gawk}/bin/awk 'NR==4 {gsub(/\.\./,""); print $4; exit}'
      '';
    in config.lib.mkDefault (toString (builtins.readFile (pkgs.runCommand "offset" {} ''
      if [ -e ${swapfilePath} ]; then
        ${offsetScript} > $out
      else
        echo "0" > $out
      fi
    '')));
  }];

  # 3. Hibernation configuration
  boot = {
    kernelParams = [
      "resume=UUID=${rootUUID}"
      "resume_offset=${toString config.swapDevices.0.resumeOffset}"
    ];
    resumeDevice = "/dev/disk/by-uuid/${rootUUID}"; 
  };

  # 4. Delay hibernation after 15 minutes sleep
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=15min
  '';

  # 5. Handle lid close/suspend key with hybrid sleep
  services.logind = {
    lidSwitch = "suspend-then-hibernate";
    lidSwitchExternalPower = "suspend-then-hibernate";
    extraConfig = ''
      HandleSuspendKey=suspend-then-hibernate
    '';
  };

  # 6. Ensure dependencies exist for offset calculation
  environment.systemPackages = [ pkgs.e2fsprogs pkgs.gawk ];
}
}

