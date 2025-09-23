{...}: 
{
  home.file.".minecraft/resourcepacks".source = ../../artifacts/minecraft/resourcepacks;
  # Need to figure out how to have two symlinks because of different settings in newer vs older versions
  #home.file.".minecraft/options.txt".source = ../../artifacts/minecraft/options.txt;
  #home.file.".minecraft/optionsLC.txt".source = ../../artifacts/minecraft/optionsLC.txt;
  #home.file.".minecraft/optionsof.txt".source = ../../artifacts/minecraft/optionsof.txt;
}