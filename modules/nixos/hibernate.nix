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
}