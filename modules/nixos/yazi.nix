{...}: {
	programs.yazi = {
		enable = true;
		#enableZshIntegration = true;
	};

	xdg.configFile."yazi/yazi.toml".source = ../../artifacts/yazi/yazi.toml;
	xdg.configFile."yazi/keymap.toml".source = ../../artifacts/yazi/keymap-default.toml;
	xdg.configFile."yazi/theme-dark".source = ../../artifacts/yazi/theme-dark.toml;
	xdg.configFile."yazi/theme-light".source = ../../artifacts/yazi/theme-light.toml;
}