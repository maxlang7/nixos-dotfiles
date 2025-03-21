{config, pkgs, ...}: 
{
  home.file.".minecraft/resourcepacks".source = ../../artifacts/minecraft/resourcepacks;
  home.file.".minecraft/options.txt".source = ../../artifacts/minecraft/options.txt;
  home.file.".minecraft/optionsLC.txt".source = ../../artifacts/minecraft/optionsLC.txt;
  home.file.".minecraft/optionsof.txt".source = ../../artifacts/minecraft/optionsof.txt;
}