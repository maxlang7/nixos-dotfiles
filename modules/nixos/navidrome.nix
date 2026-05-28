{pkgs, pkgs-unstable, lib, user, ...}:
{
  systemd.services.navidrome.serviceConfig = {
    ProtectHome = lib.mkForce false;
    BindPaths = [ "/home/${user}/Music/navidrome" ]; # Explicitly mount the music folder into the sandbox
    # Nice = -5;
    # LimitNOFILE = 65536;
  };
  services.navidrome = {
    # Switch to unstable at some point (next release)
    package = pkgs.navidrome;
    enable = true;
    settings = {
      MusicFolder = "/home/${user}/Music/navidrome";
      ImageCacheSize = "5GB";
      ScanSchedule = "@every 24h";
      EnableSharing = true;
      UIWelcomeMessage = "Musik";
      LastFM.ApiKey = "***REMOVED***";
      LastFM.Secret = "***REMOVED***";
    };
  };
}
