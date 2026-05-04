{pkgs-unstable, ...}: 
{
	programs.yazi = {
		enable = true;
		package = pkgs-unstable.yazi;
		enableZshIntegration = true;
	};
	xdg.configFile."yazi/yazi.toml".source = ../../artifacts/yazi/yazi.toml;
	xdg.configFile."yazi/keymap.toml".source = ../../artifacts/yazi/keymap.toml;
	xdg.configFile."yazi/theme-dark.toml".source = ../../artifacts/yazi/theme-dark.toml;
	xdg.configFile."yazi/theme-light.toml".source = ../../artifacts/yazi/theme-light.toml;

}