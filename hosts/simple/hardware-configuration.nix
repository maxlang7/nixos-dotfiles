{ ... }:
{
  fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
  boot.loader.grub.enable = false;
  nixpkgs.hostPlatform = "x86_64-linux";
}
