{pkgs, user, ... }:
let
  msga = pkgs.callPackage ../../packages/msga.nix { };
in
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
      ../../modules/home_manager/zed.nix
      ../../modules/home_manager/filepicker.nix
      ../../modules/home_manager/ghostty.nix
      ../../modules/home_manager/gc.nix
      # ../../modules/home_manager/claude.nix
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
      wtype
  ];
  xdg.configFile."bat/config".source = ../../artifacts/bat.conf;
  xdg.configFile."com.github.johnfactotum.Foliate/themes/foliate-gruvbox.json".source = ../../artifacts/foliate-gruvbox.json;
  # Beeper Desktop watches this file and live-injects it as custom CSS.
  xdg.configFile."BeeperTexts/custom.css".source = ../../artifacts/beeper/gruvbox.css;

  # MsgA writes its own user-level launcher on startup. Its generated Exec line
  # points past the Nix wrapper at the raw static binary, which then crashes
  # because it cannot find xkeyboard-config. Own the higher-priority launcher
  # here so app launches keep going through the wrapper.
  home.file.".local/share/applications/msga.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Name=MSGA
      Comment=Fast native Slack client
      Exec=${msga}/bin/msga %u
      Icon=msga
      Type=Application
      Categories=Network;InstantMessaging;
      StartupWMClass=msga
      MimeType=x-scheme-handler/msga;
    '';
  };

  xdg.desktopEntries = {
      reading = {
        name = "Reading";
        genericName = "Reading";
        exec = ''${pkgs.kdePackages.okular}/bin/okular "/home/${user}/Documents/books/The_Greatest_Story_Ever_Told-Bear_Grylls.pdf"'';
        icon = "okular";
        categories = [];
        settings = {
          Keywords = "Reading";
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
