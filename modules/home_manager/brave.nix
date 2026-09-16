{pkgs, pkgs-unstable, config, lib, ...}:
let
  braveDir = "${config.home.homeDirectory}/.config/BraveSoftware/Brave-Browser";
  profile = "${braveDir}/Default";
  bookmarksSnapshot = ../../artifacts/brave/Bookmarks.json;

  # pkgs-unstable.brave no longer exposes `.override`, which
  # `programs.chromium.commandLineArgs` relies on internally. Bake the
  # flags into a wrapper ourselves instead of going through that option.
  braveWrapped = pkgs-unstable.symlinkJoin {
    name = "brave-wrapped";
    paths = [ pkgs-unstable.brave ];
    nativeBuildInputs = [ pkgs-unstable.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/brave \
        --add-flags "--disable-features=AutofillSavePaymentMethods"
    '';
  };
in
{
  programs.chromium = {
    enable = true;
    package = braveWrapped;
    # NOTE: extension installs are handled declaratively (force-install) by
    # modules/nixos/brave.nix via the managed-policy file. Do NOT list
    # extensions here too — that would duplicate them as soft "External
    # Extensions" hints. This module only owns the package + launch flags.
    # commandLineArgs is intentionally NOT used here — see braveWrapped above.
  };

  # Keep the existing MIME database intact while enforcing Brave for browser
  # links and web documents on every Home Manager activation.
  home.activation.setBraveMimeDefaults =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.xdg-utils}/bin/xdg-mime default brave-browser.desktop application/xhtml+xml
      run ${pkgs.xdg-utils}/bin/xdg-mime default brave-browser.desktop text/html
      run ${pkgs.xdg-utils}/bin/xdg-mime default brave-browser.desktop x-scheme-handler/http
      run ${pkgs.xdg-utils}/bin/xdg-mime default brave-browser.desktop x-scheme-handler/https
    '';

  # Ladybird — independent from-scratch browser engine, just to try out.
  # As of 2026-05 it has NO extension support yet; re-check upstream later.
  # home.packages = [ pkgs-unstable.ladybird ];

  # Seed bookmarks into the profile ONLY on a fresh profile (no existing
  # Bookmarks file). This restores the 82-bookmark snapshot on a new machine
  # without ever clobbering the live, user-editable bookmarks day-to-day.
  # To force a re-apply: quit Brave, delete "${profile}/Bookmarks", rebuild.
  home.activation.seedBraveBookmarks =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "${profile}/Bookmarks" ]; then
        run mkdir -p "${profile}"
        run cp ${bookmarksSnapshot} "${profile}/Bookmarks"
        run chmod u+w "${profile}/Bookmarks"
        echo "seeded Brave bookmarks from snapshot"
      fi
    '';
}
