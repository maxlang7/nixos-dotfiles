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
      LastFM.ApiKey = "b79462f55320fd6ce0a5ac689c88c813";
      LastFM.Secret = "a99bdd7555040a4225a01a38eb7269e7";
    };
  };
}
