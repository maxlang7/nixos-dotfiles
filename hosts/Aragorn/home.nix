{config, pkgs, pkgs-unstable, home, ... }:
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
  home.stateVersion = "25.05"; 
  home.packages = with pkgs; [
      hello
  ];
  xdg.configFile."bat/config".source = ../../artifacts/bat.conf;
  xdg.configFile."uair/uair.toml".source = ../../artifacts/uair.toml;
  
  # For USB Drive autodetection
  services.udiskie = {
      enable = true;
      settings = {
          # workaround for
          # https://github.com/nix-community/home-manager/issues/632
          program_options = {
              # replace with your favorite file manager
              file_manager = "${pkgs.nemo-with-extensions}/bin/nemo";
          };
      };
  };
}

