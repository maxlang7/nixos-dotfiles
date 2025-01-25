{config, pkgs, ...}:
{
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  users.users.maxlang.extraGroups = [ "libvirtd" "kvm" ];
}