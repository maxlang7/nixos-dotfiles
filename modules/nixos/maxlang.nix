{pkgs, pkgs-unstable, user, ...}:
{
  imports =
    [
      ./user.nix
      ./desktop_environment_apps.nix
      #./website.nix
      #./hibernate.nix
      # ./spicetify.nix
      ./navidrome.nix
      # ./ampache.nix
      #./sops.nix
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
        signal-desktop
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
        bitwarden
        nicotine-plus
        vesktop
        shtris
        sops
        # whatsie
        imagemagick
        yubikey-manager
        ghostty
        moneydance
        # zenity
        qdirstat
        opustags
        obs-studio
        bluebubbles
        kdePackages.okular
        pymol
        python314Full
        foliate
        wl-clipboard
        video-trimmer
      ])


    ++

    (with pkgs-unstable; [
      codex
      claude-code
      # zed-editor
      yt-dlp-light
      # claude-agent-acp
      feishin
      yazi
      picard
      slack
      lunar-client
    ]);
}
