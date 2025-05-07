{config, pkgs, ...}: 
{
	xdg.configFile."rofi/config.rasi".source = ../../artifacts/rofi/config.rasi;
	xdg.configFile."rofi/gruvbox.rasi".source = ../../artifacts/rofi/gruvbox.rasi;
}