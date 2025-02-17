{config, pkgs, ...}:
{
  imports =
    [
      ./desktop_environment_apps.nix
      ./website.nix
    ];
  users.users.maxlang = {
    isNormalUser = true;
    description = "Max Langhorst";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    packages = with pkgs; [
      kitty
      brave
      discord
      mpv
      image-roll
      todoist-electron
      remnote
      inkscape
      gimp
      xfce.thunar
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
      darktable # Lightroom alternative
      gnome-boxes
      gnome-calendar
      moneydance
      signal-desktop
      obsidian
      lunar-client
      #mathematica
      fastfetch
      (vscode-with-extensions.override {
          vscode = vscodium;
          vscodeExtensions = with vscode-extensions; [
              bbenoist.nix
              ms-python.python
              ms-azuretools.vscode-docker
          ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
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