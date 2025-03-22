{...}: 
{
	programs.yazi = {
		enable = true;
		enableZshIntegration = true;
	};
	xdg.configFile."yazi/yazi.toml".source = ../../artifacts/yazi/yazi.toml;
}