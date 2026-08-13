# ════════════════════════════════════════════════════════════════════════════
#  Per-user garbage collection
# ────────────────────────────────────────────────────────────────────────────
#  NixOS's `nix.gc` runs nix-collect-garbage as root, and root only collects
#  root's profiles. Home-manager generations live under the *user's*
#  ~/.local/state/nix/profiles, so nothing was ever expiring them: 452
#  generations going back to 2025-03 had accumulated, each one pinning its
#  entire closure (old browsers, electron apps, toolchains) against the
#  system GC. This timer expires them so the weekly root GC can actually
#  reclaim the space.
# ════════════════════════════════════════════════════════════════════════════
{ ... }:
{
  nix.gc = {
    automatic = true;
    # `frequency` was renamed to `dates` in home-manager 25.11 (and the type
    # changed — it is a systemd calendar expression now, not a free string).
    dates = "weekly";
    # Matches the 30d rollback window used for system generations in
    # hosts/Aragorn/configuration.nix — keep the two in step.
    options = "--delete-older-than 30d";
  };
}
