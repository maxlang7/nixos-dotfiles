{ lib, buildGoModule, dbus, python3 }:
let
  python = python3.withPackages (p: [ p.pyyaml ]);
  checkPython = python3.withPackages (p: [ p.pyyaml p.pytest ]);
in
buildGoModule {
  pname = "blueferry-beeper";
  version = "0.1.0";
  src = ./src;
  vendorHash = "sha256-/kZn9SLVcCB1++hqL7fGetjZ9YhFgXWS1SqNtCWXXRU=";
  tags = [ "goolm" ];
  nativeCheckInputs = [ dbus ];
  env.GOTOOLCHAIN = "local";
  preCheck = ''
    export BLUEFERRY_TEST_BUS=1
  '';
  checkPhase = ''
    runHook preCheck
    dbus-run-session --config-file=${dbus}/share/dbus-1/session.conf -- go test -tags goolm ./...
    ${checkPython}/bin/python -m pytest -q test_configure.py
    runHook postCheck
  '';
  postInstall = ''
    mkdir -p $out/share/blueferry-beeper
    $out/bin/blueferry-beeper --generate-example-config --config $out/share/blueferry-beeper/example.yaml
    cp configure.py $out/share/blueferry-beeper/configure.py
    cat > $out/bin/blueferry-beeper-configure <<SCRIPT
    #!${python}/bin/python
    import runpy
    runpy.run_path("$out/share/blueferry-beeper/configure.py", run_name="__main__")
    SCRIPT
    chmod +x $out/bin/blueferry-beeper-configure
  '';
  meta = {
    description = "Encrypted Beeper bridge for BlueFerry retained text conversations";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "blueferry-beeper";
  };
}
