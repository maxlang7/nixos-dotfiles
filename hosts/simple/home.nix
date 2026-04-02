{pkgs, ... }:
{
  imports =
    [
      ../../modules/home_manager/yazi.nix
      ../../modules/home_manager/zsh.nix
    ];

  home.stateVersion = "25.05";

  xdg.configFile."bat/config".source = ../../artifacts/bat.conf;
}
