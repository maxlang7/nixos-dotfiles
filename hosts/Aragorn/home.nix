{pkgs, lib, user, ... }:
let
  msga = pkgs.callPackage ../../packages/msga.nix { };
  phoneSync = pkgs.writeShellScript "sync-from-phone" ''
    set -euo pipefail
    export RCLONE_CONFIG_PHONE_DRIVE_TYPE=drive
    export RCLONE_CONFIG_PHONE_DRIVE_ROOT_FOLDER_ID=13NxTA0yoxUXGmt-ezCHy83irvEwOnVPZ
    local_dir="/home/${user}/Downloads/Sync from Phone"
    state_dir="/home/${user}/.local/state/rclone-phone"
    ${pkgs.coreutils}/bin/mkdir -p "$local_dir" "$state_dir"
    args=(
      "$local_dir" "phone-drive:"
      --config "/home/${user}/.config/rclone/rclone.conf"
      --workdir "$state_dir/bisync"
      --check-access --check-filename .rclone-phone-access
      --drive-use-trash=true --drive-skip-gdocs
      --resilient --recover --max-lock 2m --max-delete 50
      --backup-dir1 "$state_dir/backups/$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%S)"
      --verbose
    )
    # Initialize once. Missing state on later runs must fail rather than
    # silently resync and restore files the user deliberately deleted.
    if [[ ! -e "$state_dir/initialized" ]]; then
      ${pkgs.coreutils}/bin/touch "$local_dir/.rclone-phone-access"
      ${pkgs.rclone}/bin/rclone touch "phone-drive:.rclone-phone-access" \
        --config "/home/${user}/.config/rclone/rclone.conf"
      ${pkgs.rclone}/bin/rclone bisync "''${args[@]}" --resync-mode path2
      ${pkgs.coreutils}/bin/touch "$state_dir/initialized"
    else
      ${pkgs.rclone}/bin/rclone bisync "''${args[@]}"
    fi
  '';
in
{
  # Connect headphone control for battery reports while keeping playback stereo.
  xdg.configFile."wireplumber/wireplumber.conf.d/zz-headphone-stereo.conf" = {
    force = true;
    text = ''
      monitor.bluez.rules = [
        {
          matches = [ { device.name = "bluez_card.7C_FE_62_4B_24_10" } ]
          actions = {
            update-props = {
              bluez5.auto-connect = [ a2dp_source hfp_ag ]
            }
          }
        }
      ]
      wireplumber.settings = {
        bluetooth.autoswitch-to-headset-profile = false
      }
    '';
  };
  imports =
    [
      ../../modules/home_manager/yazi.nix
      ../../modules/home_manager/zsh.nix
      #../../modules/home_manager/fish.nix
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

  systemd.user.services.rclone-cmu-drive = {
    Unit = {
      Description = "Mount the 15-112 shared Google Drive folder";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /home/${user}/Documents/112/shared_drive";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount "cmu-drive:15-112 F26 Shared" /home/${user}/Documents/112/shared_drive \
          --config=/home/${user}/.config/rclone/rclone.conf \
          --cache-dir=/home/${user}/.cache/rclone \
          --vfs-cache-mode=writes \
          --dir-cache-time=5m \
          --poll-interval=1m
      '';
      ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u /home/${user}/Documents/112/shared_drive";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    Install.WantedBy = [ "default.target" ];
  };

  # Only the OAuth credentials live privately in rclone.conf. The script
  # declares the remote type and exact personal Drive folder ID.
  systemd.user.tmpfiles.rules = [
    "d '/home/${user}/Downloads/Sync from Phone' 0700 - - -"
  ];
  systemd.user.services.rclone-phone-sync = {
    Unit = {
      Description = "Two-way sync Downloads/Sync from Phone with personal Google Drive";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${phoneSync}";
      TimeoutStartSec = "infinity";
      UMask = "0077";
    };
  };
  systemd.user.timers.rclone-phone-sync = {
    Unit.Description = "Sync phone files every two minutes";
    Timer = {
      OnStartupSec = "30s";
      OnUnitInactiveSec = "2m";
      Unit = "rclone-phone-sync.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

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
