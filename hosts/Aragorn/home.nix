{config, pkgs, home, ... }:
{
  imports =
    [
      ../../modules/home_manager/yazi.nix
      ../../modules/home_manager/zsh.nix
      ../../modules/home_manager/hyprland.nix
      ../../modules/home_manager/minecraft.nix
      ./../modules/home_manager/waybar.nix
    ];
  home.stateVersion = "24.11"; 
  home.packages = with pkgs; [
      hello
  ];
}

