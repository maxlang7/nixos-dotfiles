# Update all flake inputs and activate daily. Never reboot automatically.
{ config, pkgs, lib, user, ... }:
let
  updateInputs = pkgs.writeShellApplication {
    name = "nixos-nightly-update-inputs";
    runtimeInputs = [ config.nix.package pkgs.gitMinimal pkgs.python3 ];
    text = ''
      python3 /etc/nixos/artifacts/scripts/t3-settings-sync.py sync \
        --userdata ${lib.escapeShellArg "/home/${user}/.t3/userdata"} --if-present
      # Includes Brave and every other flake input. Explicit version pins in
      # package expressions remain pinned until those expressions are updated.
      nix flake update --flake /etc/nixos
    '';
  };
in {
  system.autoUpgrade = {
    enable = true;
    flake = "/run/nixos-upgrade/source#Aragorn";
    upgrade = false;
    flags = [ "-L" ];
    dates = "04:00"; # system timezone is America/New_York
    randomizedDelaySec = "0";
    persistent = true;
    operation = "switch";
    allowReboot = false;
  };

  systemd.services.nixos-upgrade = {
    # Update the lockfile as its owner, without staging, committing, or pushing.
    preStart = lib.mkBefore ''
      ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg user} -- \
        ${updateInputs}/bin/nixos-nightly-update-inputs
      # Archive as the checkout owner. Root only reads the resulting store path,
      # which has no .git directory and is not subject to Git ownership checks.
      source=$(${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg user} -- \
        ${config.nix.package}/bin/nix flake archive --json /etc/nixos \
        | ${pkgs.jq}/bin/jq -er '.path')
      test -f "$source/flake.nix"
      ${pkgs.coreutils}/bin/ln -sfn "$source" /run/nixos-upgrade/source
    '';
    serviceConfig = {
      RuntimeDirectory = "nixos-upgrade";
      RuntimeDirectoryMode = "0700";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };

  # Keep missed runs for the next wake/boot without waking the laptop at 4am.
  systemd.timers.nixos-upgrade.timerConfig = {
    AccuracySec = "1min";
    WakeSystem = false;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;
}
