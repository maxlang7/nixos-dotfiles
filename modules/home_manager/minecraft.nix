{config, pkgs, ...}: 
{
  home.file.".minecraft/resourcepacks".source = ../../artifacts/minecraft/resourcepacks;
}