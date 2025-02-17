{config, pkgs, ...}:
{
  imports =
    [
      ./desktop_environment_apps.nix
      ./website.nix
    ];
  users.users.maxlang = {
    isNormalUser = true;
    description = "Max Langhorst";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    packages = with pkgs; [
      php
      mariadb
    ]   
  };
}