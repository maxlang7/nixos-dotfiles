{config, pkgs, home, ... }:
{
  home.stateVersion = "24.11"; 
  
  home.packages = with pkgs; [
      hello
  ];
}

