{pkgs, user, hostName, ...}:
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
    nrs = "sudo nixos-rebuild switch --flake /etc/nixos#${hostName}";
    tree = "cbonsai -l -m '\"I am at home among the trees\" - J.R.R Tolkien'";
    cat = "bat";
    ff = "clear && fastfetch";
    dm = "yt-dlp -x --audio-format m4a --download-archive \"/home/maxlang/Music/ytdl/archive.txt\" -o \"/home/maxlang/Music/ytdl/%(title)s.%(ext)s\" \"https://www.youtube.com/playlist?list=PLTIbe5JVteQdg_7yAHxcl-WcONflu1uEQ\"";
    nrsu = "sudo nix flake update --flake /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos#${hostName}";
    ns = "nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history";
  };

  programs.zsh.enable = true;
  environment.pathsToLink = [ "/share/zsh" ];
  users.users.${user}.shell = pkgs.zsh;
}
