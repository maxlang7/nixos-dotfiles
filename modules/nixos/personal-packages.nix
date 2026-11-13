{ pkgs, pkgs-unstable, user, ... }:
{
  users.users.${user}.packages =
      (with pkgs; [
        kitty
        (pkgs.callPackage ../../packages/audio-select {})
        (pkgs.callPackage ../../packages/capture-select {})
        (pkgs.callPackage ../../packages/popup-launch {})
        audacity
        mpv
        inkscape
        gimp
        nemo-with-extensions
        #activitywatch
        #aw-watcher-window-wayland
        #awatcher
        wineWow64Packages.waylandFull
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
        typst
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
        zathura
        (pkgs.callPackage ../../packages/msga.nix {})
        qbittorrent
        google-chrome
        anki
        cloudflared
      ])


    ++

    (with pkgs-unstable; [
      obs-studio
      claude-code
      grok-build
      yt-dlp-light
      feishin
      yazi
      picard
      beeper
      codex
      vesktop
      # bluebubbles
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
      vscode
      (pkgs.callPackage ../../packages/opencode { inherit pkgs-unstable; })
      t3code
    ]);
}
