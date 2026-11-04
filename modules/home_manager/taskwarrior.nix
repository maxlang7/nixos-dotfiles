{ config, lib, pkgs, ... }: {
  home.packages = [ pkgs.taskwarrior3 pkgs.taskwarrior-tui ];
  xdg.configFile."task/gruvbox.theme" = {
    source = ../../artifacts/taskwarrior/gruvbox.theme;
    force = true;
  };
  # Keep sync credentials private, outside the world-readable Nix store.
  home.activation.taskwarriorTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    taskrc=${lib.escapeShellArg "${config.home.homeDirectory}/.taskrc"}
    theme_include=${lib.escapeShellArg "include ${config.xdg.configHome}/task/gruvbox.theme"}
    if ! ${pkgs.gnugrep}/bin/grep -Fqx "$theme_include" "$taskrc" 2>/dev/null; then
      umask 077
      printf '\n%s\n' "$theme_include" >> "$taskrc"
    fi
  '';
  # Replace the matching units installed for the immediate preview.
  xdg.configFile."systemd/user/taskwarrior-sync.service".force = true;
  xdg.configFile."systemd/user/taskwarrior-sync.timer".force = true;
  xdg.configFile."systemd/user/timers.target.wants/taskwarrior-sync.timer".force = true;
  programs.zsh.shellAliases.T = "env -u NO_COLOR taskwarrior-tui";
  systemd.user.services.taskwarrior-sync = {
    Unit.Description = "Synchronize tasks with up";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.taskwarrior3}/bin/task sync";
      UMask = "0077";
    };
  };
  systemd.user.timers.taskwarrior-sync = {
    Unit.Description = "Synchronize tasks every minute";
    Timer = { OnBootSec = "1min"; OnUnitActiveSec = "1min"; };
    Install.WantedBy = [ "timers.target" ];
  };
}
