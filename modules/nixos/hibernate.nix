{... }:
{
  # Work in progress, need to create swap which is somewhat annoying declaritvely. 
  boot.kernel.sysctl = {
    "vm.swappiness" = 60; #default linux kernel value, lower = less swap I think but seems complicated
  };
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 32*1024;
  }];
  boot.kernelParams = [
    "resume_offset=67440640"
    "mem_sleep_default=deep"
  ];
  boot.resumeDevice = "/dev/disk/by-uuid/2870-2353";
  services.logind.lidSwitch = "suspend-then-hibernate";
  services.logind.lidSwitchExternalPower = "lock";
  # Hibernate on power button pressed
  services.logind.powerKey = "hibernate";
  services.logind.powerKeyLongPress = "poweroff";
    
  # Define time delay for hibernation
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=10m
    SuspendState=mem
    HibernateOnACPower=no
  '';
}