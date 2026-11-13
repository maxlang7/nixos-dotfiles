{ pkgs, lib, config, ... }:
let
  script = ../../artifacts/scripts/t3-settings-sync.py;
  snapshot = ../../artifacts/t3;
in {
  # Ordinary writable files: T3 retains ownership of subsequent edits.
  # Rebuilds never replace an existing file or symlink.
  home.activation.seedT3Settings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.python3}/bin/python3 ${script} seed \
      --snapshot ${snapshot} \
      --userdata ${lib.escapeShellArg "${config.home.homeDirectory}/.t3/userdata"}
  '';
}
