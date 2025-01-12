{config, pkgs, ...}:
{
   users.users.bwlang = {
    isNormalUser = true;
    description = "Brad Langhorst";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    packages = with pkgs; [
      kitty
      firefox
      wine
      winetricks
      helix
      vim
    ];
  };
}