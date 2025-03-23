{config, pkgs, ...}: 
{
	xdg.configFile."rofi/config.rasi".source = ../../artifacts/rofi/config.rasi;
}