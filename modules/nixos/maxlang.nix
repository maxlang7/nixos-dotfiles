{config, pkgs, pkgs-unstable, ...}:
{
  imports =
    [
      ./desktop_environment_apps.nix
      #./website.nix
      ./hibernate.nix
      #./yazi.nix
      #../home_manager/text.nix
    ];
  # Things I want to configure more
  # Minecraft
  # Minecraft server
  # Broswer
  # Terminal
  # Zed
  # File Manager (nnn)
  # activitywatch
  # obsidian
  # waybar
  # hyprland
  # grimblast
  # theming (cursors, gruvbox)
  # rofi
  # wallpapers
  # hyprlock
  # sddm (done)
  # backups
  # networks
  users.users.maxlang = {
    isNormalUser = true;
    description = "Max Langhorst";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    packages =
      (with pkgs; [
        brave
        kitty
        discord
        mpv
        image-roll
        todoist-electron
        remnote
        inkscape
        gimp
        nemo-with-extensions
        activitywatch
        aw-watcher-window-wayland
        awatcher
        supersonic-wayland
        yt-dlp
        pdfarranger
        wine
        winetricks
        evince
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
        nnn
        evtest
        thefuck
        (lib.hiPrio pkgs.uutils-coreutils-noprefix)
    ])

    ++

    (with pkgs-unstable; [
      lunar-client
      ghostty
      sourcegit
      zed-editor
    ]);
};
}
