{...}: 
{
    environment.pathsToLink = [ "/share/zsh" ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    history = {
      append = true;
      extended = true;
      expireDuplicatesFirst = true;
      save = 1000000;
      share = true;
      size = 1000000;
    };
  };
}