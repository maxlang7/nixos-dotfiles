{pkgs, ...}:
{
  environment.systemPackages = with pkgs; [
  	neovim
  	wget
    lsof
    git
    curl
    unzip
    htop
    bat
    fzf
    fd
    ripgrep
    jq
  ];
  
  environment.shellAliases = {
    nrs = "sudo nixos-rebuild switch --flake /etc/nixos#Aragorn";
    tree = "cbonsai -l -m '\"I am at home among the trees\" - J.R.R Tolkien'";
    cat = "bat";
    ff = "clear && fastfetch";
    nrsu = "sudo nix flake update --flake /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos#Aragorn";
  };
  
  programs.zsh.enable = true;
  environment.pathsToLink = [ "/share/zsh" ];
  users.users.maxlang.shell = pkgs.zsh;
}