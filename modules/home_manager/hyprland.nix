{pkgs, ...}: 
{
  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = pkgs.hyprland;
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

	xdg.configFile."hypr/hyprland.conf".source = ../../artifacts/hypr/hyprland.conf;
}