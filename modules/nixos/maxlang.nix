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
        sway-audio-idle-inhibit
        libreoffice
        ffmpeg
        uair # timer utility
        upower
        easyeffects
        vesktop
        shtris
        sops
        imagemagick
        yubikey-manager
        ghostty
        qdirstat
        opustags
        # obs-studio
        bluebubbles
        kdePackages.okular
        pymol
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
        at
        parted
        discord
        gh
        slack
        rclone
        kiro-fhs
        (pkgs.callPackage ../../packages/msga.nix {})
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
      beeper
      # t3code
    ]);
}
