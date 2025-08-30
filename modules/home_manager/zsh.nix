{pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    oh-my-zsh = {
      enable = true; # Disable oh-my-zsh to avoid conflicts
      #theme = "gruvbox"; # Commented out as oh-my-zsh is disabled
    };
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
