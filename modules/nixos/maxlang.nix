{config, pkgs, ...}:
{
  users.users.maxlang = {
    isNormalUser = true;
    description = "Max Langhorst";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    packages = with pkgs; [
      # Desktop Environment Stuff
      waybar 
      dunst #notifications
      libnotify #notifications
      rofi-wayland #launcher
      bibata-cursors
      hyprcursor
      brightnessctl
      playerctl
      hyprpaper
      wlsunset
      #Apps
      kitty
      brave
      discord
      firefox
      mpv
      image-roll
      todoist-electron
      todoist
      remnote
      inkscape
      gimp
      pavucontrol
      xfce.thunar
      thunderbird
      activitywatch
      aw-watcher-window-wayland
      supersonic-wayland
      powertop
      trashy
      yt-dlp
      wine
      winetricks
      fastfetch
      cbonsai
      qpdf
      #xdotool

      #For Ingrid Testing
      xorg.libX11
      xorg.libXrandr
      xorg.libXext
      xorg.libxcb
      glibc
      vulkan-loader
      vulkan-tools
      mesa
      nss
      python3
      python312Packages.aw-client
      #steam-run
      (vscode-with-extensions.override {
          vscode = vscodium;
          vscodeExtensions = with vscode-extensions; [
              bbenoist.nix
              ms-python.python
              ms-azuretools.vscode-docker
              ms-vscode-remote.remote-ssh
          ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
              {
                name = "remote-ssh-edit";
                publisher = "ms-vscode-remote";
                version = "0.47.2";
                sha256 = "1hp6gjh4xp2m1xlm1jsdzxw9d8frkiidhph6nvl24d0h8z34w49g";
              }
              {
                name = "gruvbox";
                publisher = "jdinhlife";
                version = "1.19.1";
                sha256 = "sha256-mk0Iy68TuI7deQjPOygF9nXR3HB70+CBEIb2p1mdzm0=";
              }
              ];
    })
    ];
  };
}