{ craneLib }:
let
  commonArgs = {
    pname = "calendar-tui";
    version = "0.2.0";
    src = craneLib.cleanCargoSource ./.;
    strictDeps = true;
  };
  # Crane substitutes a source-free crate here, so UI edits keep this cached.
  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
craneLib.buildPackage (commonArgs // {
  inherit cargoArtifacts;
  meta.mainProgram = "calendar-tui";
})
