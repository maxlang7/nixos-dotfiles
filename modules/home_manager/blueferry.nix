{ lib, pkgs, ... }:
let
  blueferry = pkgs.callPackage ../../packages/blueferry { };
  storageSettings = pkgs.writeText "blueferry-storage-settings.py" ''
    import json
    import os
    import stat
    import tempfile
    from pathlib import Path

    directory = Path.home() / ".config/blueferry"
    target = directory / "settings.json"
    settings = {}
    if target.exists() or target.is_symlink():
        metadata = target.lstat()
        if (not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.getuid()
                or metadata.st_mode & 0o077):
            raise SystemExit("BlueFerry settings must be an owner-only regular file")
        settings = json.loads(target.read_text())
        if not isinstance(settings, dict):
            raise SystemExit("BlueFerry settings must be a JSON object")
        if settings.get("local_data") != "plaintext":
            raise SystemExit("BlueFerry storage differs from declared plaintext policy; "
                             "migrate explicitly with blueferry storage-policy-set plaintext")
    else:
        # Never reinterpret existing ciphertext as plaintext on a fresh config.
        state = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "blueferry"
        if state.exists() and any(state.iterdir()):
            raise SystemExit("BlueFerry has retained data but no storage settings; recover settings first")
    if settings.get("local_data") != "plaintext":
        settings["local_data"] = "plaintext"
        descriptor, temporary = tempfile.mkstemp(dir=directory, prefix="settings.")
        try:
            with os.fdopen(descriptor, "w") as stream:
                json.dump(settings, stream, indent=2)
                stream.write("\n")
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, target)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
  '';
  localEnvWriter = pkgs.writeShellScript "blueferry-write-config" ''
    set -euo pipefail
    umask 077
    config_dir="$HOME/.config/blueferry"
    ${pkgs.coreutils}/bin/install -d -m 0700 "$config_dir"
    temporary="$(${pkgs.coreutils}/bin/mktemp "$config_dir/local.env.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT
    {
      printf 'BLUEFERRY_MAC=%s\n' "$(< /run/secrets/blueferry-mac)"
      printf '%s\n' \
        'BLUEFERRY_ADAPTER=hci0' \
        'BLUEFERRY_ANCS_ENABLED=false' \
        'BLUEFERRY_CONTACT_PHOTOS=true' \
        'BLUEFERRY_MEDIA_CONTROL_ENABLED=true' \
        'BLUEFERRY_OTP_AUTOCOPY=true' \
        'BLUEFERRY_OTP_CLEAR_SECONDS=60'
    } > "$temporary"
    ${pkgs.coreutils}/bin/chmod 0600 "$temporary"
    ${pkgs.coreutils}/bin/mv -f "$temporary" "$config_dir/local.env"
    trap - EXIT
    ${pkgs.python3}/bin/python ${storageSettings}
  '';
in
{
  # Adopt only the exact unit created during initial setup. Unknown local
  # edits remain a Home Manager collision, and the old files are retained.
  home.activation.blueferryAdoptLegacyUnit = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    unit="$HOME/.config/systemd/user/blueferry.service"
    enabled="$HOME/.config/systemd/user/default.target.wants/blueferry.service"
    if [[ -f "$unit" && ! -L "$unit" ]] && \
       [[ "$(${pkgs.coreutils}/bin/sha256sum "$unit" | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)" == "e4950db206cb11753e6a749a2283811c8a47104230448b29717ceb27600cc7eb" ]]; then
      backup="$HOME/.local/state/blueferry-install-backup"
      run ${pkgs.coreutils}/bin/install -d -m 0700 "$backup"
      if [[ -e "$backup/legacy.service" ]]; then
        echo "BlueFerry legacy backup exists; refusing to overwrite it" >&2
        exit 1
      fi
      run ${pkgs.coreutils}/bin/mv "$unit" "$backup/legacy.service"
      if [[ -L "$enabled" ]] && [[ "$(${pkgs.coreutils}/bin/readlink "$enabled")" == "$unit" ]]; then
        run ${pkgs.coreutils}/bin/mv "$enabled" "$backup/legacy-enabled.service"
      fi
    fi
  '';

  home.activation.blueferryConfigDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.coreutils}/bin/install -d -m 0700 "$HOME/.config/blueferry" "$HOME/.local/state/blueferry"
  '';

  systemd.user.services.blueferry = {
    Unit = {
      Description = "BlueFerry iPhone Bluetooth bridge";
      Documentation = [ "https://github.com/erikwb/blueferry" ];
    };
    Service = {
      Type = "dbus";
      BusName = "io.weirdware.BlueFerry";
      ExecStartPre = "${localEnvWriter}";
      ExecStart = "${blueferry}/bin/blueferry run";
      Restart = "on-failure";
      RestartForceExitStatus = 75;
      RestartSec = 5;
      TimeoutStopSec = 180;
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ "%h/.config/blueferry" "%h/.local/state/blueferry" ];
      RestrictNamespaces = true;
      SystemCallArchitectures = "native";
      RestrictAddressFamilies = [ "AF_UNIX" ];
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      StandardOutput = "journal";
      StandardError = "journal";
    };
    Install.WantedBy = [ "default.target" ];
  };

  home.packages = [ blueferry ];
}
