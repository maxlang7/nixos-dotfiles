{pkgs, pkgs-unstable, ...}: 
{
	programs.yazi = {
		enable = true;
		package = pkgs-unstable.yazi;
		enableZshIntegration = true;
	};
	xdg.configFile."yazi/yazi.toml".source = ../../artifacts/yazi/yazi.toml;
}