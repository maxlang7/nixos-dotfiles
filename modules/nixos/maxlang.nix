{pkgs, pkgs-unstable, user, inputs, ...}:
{
  imports =
    [
      ./user.nix
      ./desktop_environment_apps.nix
      #./website.nix
      #./hibernate.nix
      # ./spicetify.nix
      ./navidrome.nix
      ./imessage-bridge.nix
      ./syncthing.nix
      # ./ampache.nix
      ./sops.nix # secrets — comment to disable (see header in sops.nix)
    ];
  boot.loader.timeout = 0;

  programs.dconf.profiles.user.databases = [{
     settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
   }];

  nix.settings.download-buffer-size = 524288000;

  environment.variables.EDITOR = "zeditor";

  programs.steam.enable = true;
  users.users.${user}.packages =
      (with pkgs; [
        kitty
        audacity
        mpv
        remnote
        inkscape
        gimp
        nemo-with-extensions
        #activitywatch
        #aw-watcher-window-wayland
        #awatcher
        wineWowPackages.waylandFull
        winetricks
        evince #pdf
        obsidian
        fastfetch
        cbonsai
        nixd
        nil
        dconf-editor # For Gnome Theming
        gruvbox-dark-gtk
        # (lib.hiPrio pkgs.uutils-coreutils-noprefix)
        sway-audio-idle-inhibit
        libreoffice
        ffmpeg
        uair # timer utility
        upower
        easyeffects
        # bitwarden-desktop moved to the pkgs-unstable list below — see there.
        nicotine-plus
        vesktop
        shtris
        sops
        # whatsie
        imagemagick
        yubikey-manager
        ghostty
        # moneydance — removed 2026-08-12. It pulls
        # `openjdk25.override { enableJavaFX = true; }`, a derivation no
        # binary cache has ever built, so every nixpkgs bump that moves the
        # JDK forced a full from-source OpenJDK+OpenJFX compile locally.
        # zenity
        qdirstat
        opustags
        # obs-studio
        bluebubbles
        kdePackages.okular
        pymol
        # `python314Full` was removed in 25.11 — the "Full" variants existed to
        # add bluetooth/tkinter, both of which the base package now covers.
        python314
        foliate
        wl-clipboard
        video-trimmer
        nodejs-slim_latest
        btop
        clipse
        imv
        zip
        nix-search-tv
        lunar-client
      ])


    ++

    (with pkgs-unstable; [
      # 25.11 renamed `bitwarden` -> `bitwarden-desktop`, but that build pins
      # electron-39.8.10, which nixpkgs marks INSECURE. Rather than add it to
      # permittedInsecurePackages — a knowingly-vulnerable Electron under a
      # password manager is the worst place to make that trade — take the
      # unstable build (2026.7.0), which is on a patched Electron.
      # Move this back to the stable list once 25.11 ships a fixed electron.
      bitwarden-desktop
      claude-code
      yt-dlp-light
      feishin
      yazi
      picard
      slack
      # lunar-client
      obs-studio
      signal-desktop
      beeper
      # t3code
    ]);
}
