{lib, ...}:
{
  systemd.services.navidrome.serviceConfig.ProtectHome = lib.mkForce false;
  services.navidrome = {
    enable = true;
    settings = {
      MusicFolder = "/home/maxlang/Music/navidrome";
      EnableSharing = true;
      UIWelcomeMessage = "Musik";
      LastFM.ApiKey = "194e34c66e3815c10e97baca8f6f5ac6";
      LastFM.Secret = "36e02bd964081a5937875b82d6ca9c26";
    };
  };
  
}