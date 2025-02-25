{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hibernate.nix
    ];
    
  powerManagement = {
    enable = true;
    powertop.enable = true;
  };

  # Better scheduling for CPU cycles (System76 scheduler)
  services.system76-scheduler.settings.cfsProfiles.enable = true;

  # Disable power-profiles-daemon (TLP is generally better)
  services.power-profiles-daemon.enable = false;

  # Enable TLP (power management tool)
  services.tlp = {
    enable = true;
    settings = {
      # CPU settings
      CPU_BOOST_ON_AC = 1;  # Enable CPU boost on AC power
      CPU_BOOST_ON_BAT = 0; # Disable CPU boost on battery power
      CPU_SCALING_GOVERNOR_ON_AC = "performance"; # Performance governor on AC
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";   # Powersave governor on battery

      # USB autosuspend
      USB_AUTOSUSPEND = 1;                      # Enable USB autosuspend
      USB_AUTOSUSPEND_DISABLE_ON_WAKEUP = 1; # Recommended

      # Runtime power management for PCI(e) devices
      RUNTIME_PM_ON_BAT = "auto"; # Auto power management on battery
      RUNTIME_PM_ON_AC = "auto";  # Auto power management on AC

      # Disable Wake-on-LAN
      WOL_DISABLE = "Y"; # Disable Wake-on-LAN
    };
  };

  # Enable thermald (thermal management daemon)
  services.thermald.enable = true;

  # Swap file configuration (for hibernation
}

