{config, pkgs, ...}: 
{
  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = pkgs.hyprland;
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}