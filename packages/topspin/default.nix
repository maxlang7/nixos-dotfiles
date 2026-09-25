# Bruker TopSpin under Wine.
#
# The native Linux build was the first attempt; it runs, but CodeMeter's online
# licence activation never worked (the WebDepot's WebSocket API on 22352 stays
# silent, error 0x18088003). The Windows stack is the one Bruker and WIBU actually
# test, so run that under Wine instead.
#
# Nix owns the wrapper scripts, the Wine build and the .desktop entry. It does not
# own the prefix contents: TopSpin is a multi-GB proprietary installer that has to
# be fetched from a Bruker account, so `topspin-wine-setup` populates the prefix
# imperatively and stamps each stage. Same trade-off the rest of this config makes
# for installers Nix cannot fetch.
{ lib
, symlinkJoin
, writeShellApplication
, wineWow64Packages
, winetricks
, coreutils
, findutils
, procps
}:

let
  wine = wineWow64Packages.waylandFull;

  runtimeInputs = [
    wine
    winetricks
    coreutils
    findutils
    procps
  ];

  setup = writeShellApplication {
    name = "topspin-wine-setup";
    inherit runtimeInputs;
    text = builtins.readFile ./topspin-wine-setup.sh;
  };

  # The launcher shells out to the setup script when the prefix is missing.
  launcher = writeShellApplication {
    name = "topspin";
    runtimeInputs = runtimeInputs ++ [ setup ];
    text = builtins.readFile ./topspin.sh;
  };
in
symlinkJoin {
  name = "topspin-wine";
  paths = [ launcher setup ];

  meta = {
    description = "Bruker TopSpin launcher and Wine prefix bootstrapper";
    license = lib.licenses.mit; # the wrappers; TopSpin itself is proprietary
    platforms = lib.platforms.linux;
    mainProgram = "topspin";
  };
}
