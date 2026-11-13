{ pkgs-unstable }:
pkgs-unstable.stdenv.mkDerivation {
  pname = "opencode";
  version = "2.2.6";
  src = pkgs-unstable.fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v2.2.6/opencode-linux-x64.tar.gz";
    hash = "sha256-CLsh1jJs50DZHM5+voimU2kz9uHjA1O5GgawHyXaMGw=";
  };
  sourceRoot = ".";
  nativeBuildInputs = with pkgs-unstable; [ autoPatchelfHook makeWrapper ];
  buildInputs = with pkgs-unstable; [ stdenv.cc.cc.lib wayland ];
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 opencode $out/bin/opencode
    wrapProgram $out/bin/opencode \
      --set OPENCODE_DISABLE_AUTOUPDATE true \
      --suffix PATH : ${pkgs-unstable.lib.makeBinPath [ pkgs-unstable.ripgrep ]} \
      --prefix LD_LIBRARY_PATH : ${pkgs-unstable.lib.makeLibraryPath [ pkgs-unstable.wayland ]}
    runHook postInstall
  '';
  meta.mainProgram = "opencode";
}
