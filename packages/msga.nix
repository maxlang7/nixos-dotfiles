{
  lib,
  stdenvNoCC,
  fetchurl,
  makeDesktopItem,
  makeWrapper,
  writeShellScriptBin,
  xkeyboard_config,
}:

let
  braveBrowserShim = writeShellScriptBin "brave-browser" ''
    exec brave "$@"
  '';

  desktopItem = makeDesktopItem {
    name = "msga";
    desktopName = "MSGA";
    comment = "Fast native Slack client";
    exec = "msga %u";
    icon = "msga";
    categories = [ "Network" "InstantMessaging" ];
    startupWMClass = "msga";
    mimeTypes = [ "x-scheme-handler/msga" ];
  };
in
stdenvNoCC.mkDerivation {
  pname = "msga";
  version = "24";

  src = fetchurl {
    url = "https://msga.app/download/msga-linux-x86_64";
    hash = "sha256-k1YpWUVsP8NoDj+Mat71oBEHR/8rTM47MEUUTAHAwv4=";
  };

  icon = fetchurl {
    url = "https://raw.githubusercontent.com/punarinta/make-slack-great-again/a36aabd14bc92a1ec67f86dd60a5f2d364a18ace/gfx/icon_256.png";
    hash = "sha256-lnwtC6WgrPxhIvTXbc0q1XGEflO8SpOMtvATOWw7IX8=";
  };

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/msga"
    install -Dm644 "$icon" "$out/share/icons/hicolor/256x256/apps/msga.png"
    mkdir -p "$out/share/applications"
    cp "${desktopItem}/share/applications/msga.desktop" "$out/share/applications/"

    wrapProgram "$out/bin/msga" \
      --set XKB_CONFIG_ROOT "${xkeyboard_config}/share/X11/xkb" \
      --prefix PATH : "${braveBrowserShim}/bin"

    runHook postInstall
  '';

  meta = {
    description = "Native C++/Qt6 Slack client";
    homepage = "https://msga.app/";
    license = lib.licenses.gpl3Only;
    mainProgram = "msga";
    platforms = [ "x86_64-linux" ];
  };
}
