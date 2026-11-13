{ pkgs, user, ... }:
let
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
in {
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
        ${pkgs.rclone}/bin/rclone mount "cmu-drive:" /home/${user}/Documents/112/shared_drive \
          --drive-root-folder-id=1-0siBJgE3zioxyWbGkq813KqcWpW2PBF \
          --config=/home/${user}/.config/rclone/rclone.conf \
          --cache-dir=/home/${user}/.cache/rclone \
          --vfs-cache-mode=writes \
          --dir-cache-time=5m \
          --poll-interval=1m
      '';
      # NixOS's privileged wrapper can detach the mount even if a file manager holds it open.
      ExecStop = "/run/wrappers/bin/fusermount3 -uz /home/${user}/Documents/112/shared_drive";
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

  # Download the CMU Drive School folder. Never upload or delete local files.
  systemd.user.services.rclone-school-pull = {
    Unit = {
      Description = "Download CMU Google Drive School folder";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      UMask = "0077";
      TimeoutStartSec = "infinity";
      ExecStart = pkgs.writeShellScript "pull-school-drive" ''
        set -euo pipefail
        ${pkgs.rclone}/bin/rclone copy cmu-drive: "/home/${user}/Documents/School/Google Drive" \
          --config "/home/${user}/.config/rclone/rclone.conf" \
          --drive-root-folder-id 1Gj2adTp4jIGuwrV9gvSDfFK3PYNvvblA \
          --drive-export-formats docx,xlsx,pptx,svg \
          --backup-dir "/home/${user}/.local/state/rclone-school/backups/$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%S%N)" \
          --create-empty-src-dirs --verbose
      '';
    };
  };
  systemd.user.timers.rclone-school-pull = {
    Unit.Description = "Download School files every five minutes";
    Timer = {
      OnStartupSec = "1m";
      OnUnitInactiveSec = "5m";
      Unit = "rclone-school-pull.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

}
