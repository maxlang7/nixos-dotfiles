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
      ./autoupgrade.nix
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
        inkscape
        gimp
        nemo-with-extensions
        #activitywatch
        #aw-watcher-window-wayland
        #awatcher
        wineWowPackages.waylandFull
        winetricks
        evince #pdf
        fastfetch
        cbonsai
        dconf-editor # For Gnome Theming
        gruvbox-dark-gtk
        sway-audio-idle-inhibit
        libreoffice
        uair # timer utility
        upower
        easyeffects
        shtris
        sops
        yubikey-manager
        ghostty
        qdirstat
        opustags
        # obs-studio
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
        at
        parted
        bitwarden-desktop
        (pkgs.callPackage ../../packages/msga.nix {})
      ])


    ++

    (with pkgs-unstable; [
      claude-code
      yt-dlp-light
      feishin
      yazi
      picard
      beeper
      codex
      vesktop
      discord
      slack
      bluebubbles
      lunar-client
      obsidian
      remnote
      kiro-fhs
      ffmpeg
      imagemagick
      gh
      rclone
      nixd
      nil
      # t3code
    ]);
}
