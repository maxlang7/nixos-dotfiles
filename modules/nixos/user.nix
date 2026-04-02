{pkgs, user, ...}:
{
  users.users.${user} = {
    isNormalUser = true;
    description = "Max Langhorst";
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };
}
