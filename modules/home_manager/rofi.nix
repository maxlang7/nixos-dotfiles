{config, pkgs, ...}: 
{
	xdg.configFile."rofi/config.rasi".source = ../../artifacts/rofi/config.rasi;
	xdg.configFile."rofi/gruvbox-dark-hard.rasi".source = ../../artifacts/rofi/gruvbox-dark-hard.rasi;
}