{pkgs, lib, user, hostName, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/nixos/desktop-common.nix
      ../../modules/nixos/battery_management.nix
      ../../modules/nixos/terminal_utils.nix
      ../../modules/nixos/maxlang.nix
      ../../modules/nixos/sddm.nix
      #../../modules/nixos/firefox.nix
      ../../modules/nixos/hyprland.nix
      ../../modules/nixos/networking.nix
      ../../modules/nixos/bluetooth.nix
      ../../modules/nixos/minecraft_server.nix
    ];

  networking.hostName = hostName;

  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 3d";
    };
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.sessionVariables = {
    TERMINAL = "ghostty";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
