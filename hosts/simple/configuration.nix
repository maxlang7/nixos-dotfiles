{pkgs, hostName, user, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ../../modules/nixos/user.nix
      ../../modules/nixos/terminal_utils.nix
    ];

  networking.hostName = hostName;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "24.11";
}
