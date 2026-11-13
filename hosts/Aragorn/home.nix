{pkgs, lib, user, userApps, ... }:
let
  calendarTui = userApps.calendarTui;
  msga = pkgs.callPackage ../../packages/msga.nix { };

in
{
  imports =
    [
      ../../modules/home_manager/audio.nix
      ../../modules/home_manager/rclone.nix
      ../../modules/home_manager/yazi.nix
      ../../modules/home_manager/zsh.nix
      ../../modules/home_manager/taskwarrior.nix
      ../../modules/home_manager/codex-shortcuts.nix
      ../../modules/home_manager/t3-settings.nix
      ../../modules/home_manager/hyprland.nix
      ../../modules/home_manager/minecraft.nix
      ../../modules/home_manager/waybar.nix
      ../../modules/home_manager/notifications.nix
      ../../modules/home_manager/rofi.nix
      ../../modules/home_manager/brave.nix
      ../../modules/home_manager/hypridle.nix
      ../../modules/home_manager/zed.nix
      ../../modules/home_manager/filepicker.nix
      ../../modules/home_manager/ghostty.nix
      ../../modules/home_manager/system-monitors.nix
      ../../modules/home_manager/gc.nix
      ../../modules/home_manager/topspin.nix
    ];

  home.stateVersion = "25.05";
  # One wake-up every five minutes; the app refreshes the full cache hourly.
  systemd.user.services.calendar-tui-sync = {
    Unit.Description = "Sync CMU Google Calendar cache";
    Service = {
      Type = "oneshot";
      ExecStart = "${calendarTui}/bin/calendar-tui --sync";
      TimeoutStartSec = "10min";
      UMask = "0077";
    };
  };
  systemd.user.timers.calendar-tui-sync = {
    Unit.Description = "Refresh CMU calendar every five minutes";
    Timer = {
      OnCalendar = "*-*-* *:0/5:00";
      Persistent = true;
      AccuracySec = "15s";
    };
    Install.WantedBy = [ "timers.target" ];
  };
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
  xdg.configFile."kwalletrc".text = ''
      [Wallet]
      Enabled=false
      First Use=false
  '';

  # For USB Drive autodetection
  services.udiskie = {
      enable = true;
      automount = true;
      tray = "never";
      settings = {
          # workaround for
          # https://github.com/nix-community/home-manager/issues/632
          program_options = {
              # replace with your favorite file manager
              file_manager = "${pkgs.nemo-with-extensions}/bin/nemo";
          };
      };
  };

  # This Hyprland session does not start graphical-session.target.
  systemd.user.services.udiskie = {
    Install.WantedBy = lib.mkForce [ "default.target" ];
    Unit.After = lib.mkForce [ ];
    Unit.PartOf = lib.mkForce [ ];
    Service.Restart = "on-failure";
  };
}
