{config, pkgs, ...}:
{
  powerManagement = {
    enable = true;
    powertop.enable = true;

  };

  # Better scheduling for CPU cycles
  services.system76-scheduler.settings.cfsProfiles.enable = true;
  
  services.power-profiles-daemon.enable = false;
  
  # Enable TLP (better than gnomes internal power manager)
  services.tlp = {
    enable = true;
    settings = {
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    };
  };

  services.thermald.enable = true;

}