{pkgs, ... }:
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
      ../../modules/home_manager/hypridle.nix
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
  
  xdg.desktopEntries = {
      international-relations = {
        name = "International Relations";
        genericName = "Textbook";
        exec = ''${pkgs.kdePackages.okular}/bin/okular "/home/maxlang/Documents/School/CMU/26_Freshman_Spring/84226 (International Relations)/Essentials of International Relations (Ninth Edition) (Karen A. Mingst Heather Elko McKibben) (Z-Library).pdf"'';
        icon = "okular";
        categories = [ "Education" ];
        settings = {
          Keywords = "Politics;Study;IR";
        };
      };
    };
  xdg.configFile.".config/kwalletrc".text = ''
      [Wallet]
      Enabled=false
      First Use=false
  '';
  
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

