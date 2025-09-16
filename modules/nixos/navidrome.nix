{lib, ...}:
{
  systemd.services.navidrome.serviceConfig.ProtectHome = lib.mkForce false;
  services.navidrome = {
    enable = true;
    settings = {
      MusicFolder = "/home/maxlang/Music/navidrome";
      EnableSharing = true;
      UIWelcomeMessage = "Testing";
    };
  };
  
}