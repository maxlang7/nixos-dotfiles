{config, pkgs, ...}:
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
    fish
    ];
  environment.pathsToLink = [ "/share/zsh" ];
  environment.shellAliases = {
    nrs = "sudo nixos-rebuild switch --flake /etc/nixos#Aragorn";
    td = "todoist-electron --enable-features=UseOzonePlatform --ozone-platform=wayland";
    tree = "cbonsai -l -m '\"I am at home among the trees\" - J.R.R Tolkien'";
    cat = "bat";
  };
  users.users.maxlang.shell = pkgs.fish;
}