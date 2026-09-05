# Nightly automatic flake update + rebuild, at 03:00 local time.
#
# Bumps the flake inputs (so `nixpkgs-unstable` actually moves — without
# --update-input a flake rebuild just honours the existing lockfile and nothing
# changes) and switches to the new generation.
#
# Deliberately conservative:
#   - allowReboot = false. A kernel bump stages the new generation; it takes
#     effect at your next manual reboot. The machine is never rebooted out from
#     under a running session.
#   - --commit-lock-file writes the updated flake.lock back as a local commit in
#     /etc/nixos, so git stays the source of truth for what's actually running.
#     These commits are NOT pushed; `git log` here will show root's nightly
#     "flake.lock: Update" commits to push or squash at your leisure.
#   - persistent = true so a run missed because the laptop was asleep at 03:00
#     (the common case for Aragorn) fires on the next boot instead of vanishing.
#   - randomizedDelaySec spreads the fetch instead of hitting cache.nixos.org at
#     exactly 03:00:00 along with everyone else.
#
# Rollback: pick the previous generation in the boot menu, or
# `nixos-rebuild switch --rollback`.
{ config, pkgs, lib, ... }:
{
  system.autoUpgrade = {
    enable = true;
    flake = "/etc/nixos";
    flags = [
      "--update-input" "nixpkgs"
      "--update-input" "nixpkgs-unstable"
      "--update-input" "home-manager"
      "--commit-lock-file"
      "-L" # full build logs, so journalctl -u nixos-upgrade is useful
    ];
    dates = "03:00";
    randomizedDelaySec = "30min";
    persistent = true;
    allowReboot = false;
  };

  # Every nightly run leaves another generation behind; without this the store
  # grows without bound. 30d keeps plenty of rollback targets.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;
}
