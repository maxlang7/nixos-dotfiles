{config, pkgs, pkgs-unstable, ...}:
{
  imports =
    [
      ./desktop_environment_apps.nix
      #./website.nix
      ./hibernate.nix
    ];
  users.users.maxlang = {
    isNormalUser = true;
    description = "Max Langhorst";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    packages =
      (with pkgs; [
        kitty
        discord
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
        gnome-calendar
        signal-desktop
        obsidian
        #mathematica
        fastfetch
        cbonsai
        nixd
        nil
        dconf-editor # For Gnome Theming
        gruvbox-dark-gtk
        moneydance
        jq # Json parser
        evtest
        thefuck
        (lib.hiPrio pkgs.uutils-coreutils-noprefix)
        python314
        strawberry
        et
        sway-sway-audio-idle-inhibit
    ])

    ++

    (with pkgs-unstable; [
      lunar-client
      ghostty
      sourcegit
      zed-editor
      supersonic-wayland
      hollywood
    ]);
};
}
