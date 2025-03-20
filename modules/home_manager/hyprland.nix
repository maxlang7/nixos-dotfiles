{config, pkgs, ...}: 
{
	xdg.configFile."hypr/hyprland.conf".source = ../../artifacts/hypr/hyprland.conf;
}