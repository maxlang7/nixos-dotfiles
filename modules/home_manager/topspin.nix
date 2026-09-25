# Bruker TopSpin, running under Wine.
#
# See packages/topspin/default.nix for why Wine rather than the native Linux build.
# What is declarative here: the Wine build, the launcher and setup wrappers, the
# desktop entry and its icons, and a login-time unit that makes sure the prefix
# exists. What is not: the TopSpin installer itself, which is a multi-GB download
# from a Bruker account — `topspin-wine-setup <installer>.exe` puts that in.
{ pkgs, ... }:

let
  topspin = pkgs.callPackage ../../packages/topspin { };
in
{
  home.packages = [ topspin ];

  xdg.dataFile."icons/hicolor/48x48/apps/topspin.png".source =
    ../../artifacts/topspin/topspin-48.png;
  xdg.dataFile."icons/hicolor/128x128/apps/topspin.png".source =
    ../../artifacts/topspin/topspin-128.png;
  xdg.dataFile."icons/hicolor/256x256/apps/topspin.png".source =
    ../../artifacts/topspin/topspin-256.png;

  # Keywords are the ones Bruker's own installer writes into its Linux desktop
  # file (installer/etc/shortcuts.yaml). No StartupWMClass: Wine's window class
  # for this is unverified, and a wrong one is worse than none.
  xdg.desktopEntries.topspin = {
    name = "TopSpin";
    genericName = "NMR Data Analysis";
    comment = "Bruker TopSpin — NMR acquisition and processing";
    exec = "${topspin}/bin/topspin";
    icon = "topspin";
    terminal = false;
    categories = [ "Science" "Education" "Chemistry" ];
    settings.Keywords = "nmr;spectra;spectrum;spectrometer;scu;bruker;";
  };

  # Creating the prefix takes a couple of minutes and pulls ~100 MB through
  # winetricks, so it does not belong in a home-manager activation script — that
  # would stall every nixos-rebuild switch. A oneshot at login does the same job
  # out of the way and no-ops once the stage stamps exist.
  #
  # default.target, not graphical-session.target: Hyprland here never activates
  # the latter (it is inactive even mid-session), so a unit wanted by it would
  # simply never run. This is the same target the rclone unit in home.nix uses.
  # If it fires before the compositor has exported a display the script exits 0
  # without doing anything, and the launcher builds the prefix on first use.
  systemd.user.services.topspin-wine-prefix = {
    Unit = {
      Description = "Create the TopSpin Wine prefix if it is missing";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${topspin}/bin/topspin-wine-setup --prefix-only";
      TimeoutStartSec = "20min";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
