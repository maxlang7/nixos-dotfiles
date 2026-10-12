{ lib, python3Packages, fetchFromGitHub, wrapGAppsHook4, gobject-introspection,
  gtk4, libadwaita, libsecret, bluez, systemd, wireplumber, wl-clipboard, xdg-utils }:
let
  revision = "c719bef1fc2111dad17376f854d4306afa6a5a21";
  patch = ./recent-inbox.patch;
  contentSha = builtins.hashString "sha256" (revision + builtins.hashFile "sha256" patch);
in
python3Packages.buildPythonApplication {
  pname = "blueferry";
  version = "0.8.1";
  pyproject = true;
  src = fetchFromGitHub {
    owner = "erikwb";
    repo = "blueferry";
    rev = revision;
    hash = "sha256-wIfrbBPz2HgkoCrmPOUAIjKwH2SroFaqBA6QCEZV63Y=";
  };
  patches = [ patch ];
  build-system = with python3Packages; [ setuptools wheel ];
  dependencies = with python3Packages; [ cryptography typer dbus-python pygobject3 ];
  nativeBuildInputs = [ wrapGAppsHook4 gobject-introspection ];
  buildInputs = [ gtk4 libadwaita libsecret ];
  # Resolve distribution-specific paths at build time, never through the
  # invoking user's PATH in an authorization decision.
  postPatch = ''
    substituteInPlace src/blueferry/service_manager.py src/blueferry/bluez_setup.py src/blueferry/bluetooth_capabilities.py \
      --replace-warn /usr/bin/systemctl ${systemd}/bin/systemctl
    substituteInPlace src/blueferry/bluetooth_capabilities.py src/blueferry/bluez_setup.py \
      --replace-fail /usr/bin/btmgmt ${bluez}/bin/btmgmt
    substituteInPlace src/blueferry/bluez_setup.py \
      --replace-fail /usr/lib/blueferry/blueferry-set-cod /run/current-system/sw/bin/blueferry-set-cod
    substituteInPlace src/blueferry/wireplumber_policy.py \
      --replace-fail /usr/bin/wireplumber ${wireplumber}/bin/wireplumber
    substituteInPlace src/blueferry/client_activation.py \
      --replace-fail /usr/bin/blueferry- $out/bin/blueferry-
    substituteInPlace src/blueferry/build_info.py src/blueferry/backend_lifecycle.py \
      --replace-warn /usr/share/blueferry $out/share/blueferry
  '';
  dontWrapGApps = true;
  preFixup = ''
    makeWrapperArgs+=("''${gappsWrapperArgs[@]}" --prefix PATH : ${lib.makeBinPath [ bluez systemd wl-clipboard xdg-utils ]}:${bluez}/libexec/bluetooth)
  '';
  postInstall = ''
    # Ship only clients whose dependencies are provided by this package.
    rm -f $out/bin/blueferry-qt $out/bin/blueferry-tui $out/bin/blueferry-quickshell-bridge
    mkdir -p $out/share/blueferry
    echo ${contentSha} > $out/share/blueferry/build-sha
    echo 0.8.1-nix-${builtins.substring 0 12 contentSha} > $out/share/blueferry/package-release
    install -Dm644 data/io.weirdware.BlueFerry.Gtk.desktop $out/share/applications/io.weirdware.BlueFerry.Gtk.desktop
    substituteInPlace $out/share/applications/io.weirdware.BlueFerry.Gtk.desktop \
      --replace-fail Exec=blueferry-gtk Exec=$out/bin/blueferry-gtk
    install -Dm644 docs/images/blueferry.svg $out/share/icons/hicolor/scalable/apps/io.weirdware.BlueFerry.svg
  '';
  nativeCheckInputs = with python3Packages; [ pytest hypothesis ];
  checkPhase = ''
    runHook preCheck
    pytest -q tests/test_recent_history.py tests/test_daemon_pairing_policy.py tests/test_map_query.py tests/test_backend_operations.py
    runHook postCheck
  '';
  pythonImportsCheck = [ "blueferry" "blueferry.recent_history" ];
  meta = {
    description = "iPhone messages and contacts over Bluetooth";
    homepage = "https://github.com/erikwb/blueferry";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    mainProgram = "blueferry";
  };
}
