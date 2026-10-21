{ lib, stdenvNoCC, fetchurl, dpkg, buildFHSEnv, writeShellScriptBin, symlinkJoin }:
let
  payload = stdenvNoCC.mkDerivation {
    pname = "codemeter-runtime-payload";
    version = "9.10.8178.501";
    src = fetchurl {
      url = "https://www.wibu.com/support/user/user-software/file/download/18348.html?tx_wibudownloads_downloadlist%5BdirectDownload%5D=directDownload&tx_wibudownloads_downloadlist%5BuseAwsS3%5D=0&cHash=8dba7ab094dec6267346f04fce2a2bcd";
      name = "codemeter_9.10.8178.501_amd64.deb";
      hash = "sha256-fPuJZSzKH0FNHjLQWFsa6nlcTY0H1BQaU1Bp9MwAiEQ=";
    };
    nativeBuildInputs = [ dpkg ];
    unpackPhase = ''
      mkdir payload
      dpkg-deb --fsys-tarfile $src | tar --extract --no-same-owner --no-same-permissions --directory payload
    '';
    installPhase = ''
      mkdir -p $out/bin $out/sbin $out/lib $out/share
      cp -a payload/usr/bin/cmu $out/bin/
      cp -a payload/usr/sbin/. $out/sbin/
      cp -a payload/usr/lib/x86_64-linux-gnu/. $out/lib/
      cp -a payload/usr/share/doc $out/share/
    '';
    # Keep the vendor executables intact; run them in an FHS environment.
    dontFixup = true;
  };
  fhs = buildFHSEnv {
    name = "codemeter-fhs";
    unshareUser = false;
    runScript = "bash";
    targetPkgs = p: with p; [
      glibc stdenv.cc.cc.lib openssl zlib libusb1 systemd util-linux procps
      fontconfig freetype libGL libxkbcommon
      libx11 libxext libice libsm libxcb
      libxcb-wm libxcb-image libxcb-keysyms libxcb-render-util
    ];
    extraBwrapArgs = [
      "--tmpfs /opt"
      "--ro-bind ${payload} /opt/codemeter"
      "--bind /var/lib/codemeter-config /etc/wibu/CodeMeter"
    ];
    profile = ''
      export LD_LIBRARY_PATH=/opt/codemeter/lib:''${LD_LIBRARY_PATH:-}
      export PATH=/opt/codemeter/bin:/opt/codemeter/sbin:$PATH
    '';
  };
  cmu = writeShellScriptBin "codemeter-cmu" ''
    exec ${fhs}/bin/codemeter-fhs -c 'exec /opt/codemeter/bin/cmu "$@"' -- "$@"
  '';
in
symlinkJoin {
  name = "codemeter-runtime-9.10";
  paths = [ fhs cmu ];
  passthru = { inherit payload; };
  meta = {
    description = "WIBU CodeMeter runtime for local TopSpin licensing";
    homepage = "https://www.wibu.com/support/user/user-software.html";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
