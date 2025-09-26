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
  boot.resumeDevice = "/var/lib/swapfile";
  services.logind.lidSwitch = "suspend-then-hibernate";
    # Hibernate on power button pressed
  services.logind.powerKey = "hibernate";
  services.logind.powerKeyLongPress = "poweroff";
  
    # Suspend first
  boot.kernelParams = ["mem_sleep_default=deep"];
  
    # Define time delay for hibernation
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=10m
    SuspendState=memHibernateOnACPower=
    HibernateOnACPower=no
  '';
}