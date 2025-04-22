{config, pkgs, home, ... }:
{
  imports =
    [
      ../../modules/home_manager/yazi.nix
      ../../modules/home_manager/zsh.nix
      #../../modules/home_manager/fish.nix
      ../../modules/home_manager/hyprland.nix
      ../../modules/home_manager/minecraft.nix
      ../../modules/home_manager/waybar.nix
      ../../modules/home_manager/rofi.nix
      ../../modules/home_manager/brave.nix
      ../../modules/home_manager/hyprlock.nix
    ];
    # Things I want to configure more
    # Minecraft server
    # Browser
    # Terminal
    # Zed
    # File Manager (yazi) DONE
    # activitywatch
    # obsidian
    # waybar DONE
    # hyprland DONE
    # grimblast
    # theming (cursors, gruvbox)
    # rofi DONE
    # wallpapers DONE
    # hyprlock
    # sddm (done)
    # backups
    # networks
  home.stateVersion = "24.11"; 
  home.packages = with pkgs; [
      hello
  ];
  xdg.configFile."bat/config".source = ../../artifacts/bat.conf;
}

