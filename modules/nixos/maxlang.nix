{pkgs, pkgs-unstable, ...}:
{
  imports =
    [
      ./desktop_environment_apps.nix
      #./website.nix
      ./hibernate.nix
      #./spicetify.nix
      ./navidrome.nix
      #./sops.nix
    ];
  boot.loader.timeout = 0;

  programs.steam.enable = true;
  users.users.maxlang = {
    isNormalUser = true;
    description = "Max Langhorst";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    packages =
      (with pkgs; [
        kitty
        audacity
        mpv
        todoist-electron
        remnote
        inkscape
        gimp
        nemo-with-extensions
        activitywatch
        aw-watcher-window-wayland
        awatcher
        yt-dlp
        pdfarranger
        wine
        winetricks
        evince #pdf
        signal-desktop
        obsidian
        #mathematica
        fastfetch
        cbonsai
        nixd
        nil
        dconf-editor # For Gnome Theming
        gruvbox-dark-gtk
        (lib.hiPrio pkgs.uutils-coreutils-noprefix)
        python313
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
        whatsie
        imagemagick
        yubikey-manager
        lunar-client
        ghostty
        moneydance
        nix-prefetch-github
        slack
        zenity
    ])

    ++

    (with pkgs-unstable; [
      zed-editor
      feishin
      yazi
      spotdl
      xdg-desktop-portal-termfilechooser
      picard
    ]);
    
  };
}
