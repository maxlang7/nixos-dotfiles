{pkgs, pkgs-unstable, lib, config, user, ...}:
{
  systemd.services.navidrome.serviceConfig = {
    ProtectHome = lib.mkForce false;
    BindPaths = [ "/home/${user}/Music/navidrome" ]; # Explicitly mount the music folder into the sandbox
    # Nice = -5;
    # LimitNOFILE = 65536;

    # ┌─ sops secret (requires ./sops.nix) ──────────────────────────────────┐
    # │ LastFM ApiKey/Secret injected via env file (ND_LASTFM_*). To revert  │
    # │ to plaintext: comment the next line + uncomment the LastFM.* lines    │
    # │ in `settings` below.                                                  │
    EnvironmentFile = config.sops.templates."navidrome.env".path;
    # └──────────────────────────────────────────────────────────────────────┘
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
      # LastFM keys come from sops via the EnvironmentFile above (ND_LASTFM_*).
      # Plaintext is NOT kept here. To inspect/restore values:
      #   sops -d artifacts/sops/secrets/secrets.yaml
      # A convenience copy lives in artifacts/sops/PLAINTEXT-REFERENCE.md (gitignored).
    };
  };
}
