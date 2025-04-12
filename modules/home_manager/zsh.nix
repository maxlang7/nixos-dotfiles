{pkgs, ...}: 
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    # oh-my-zsh = {
    #   enable = true;
    #   theme = 
    # };
    history = {
      append = true;
      extended = true;
      expireDuplicatesFirst = true;
      ignoreDups = true;
      ignoreSpace = true;
      save = 1000000;
      share = true;
      size = 1000000;
    };
  };
}