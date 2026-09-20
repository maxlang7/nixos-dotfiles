{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = [
    pkgs.python3
    pkgs.gpu-screen-recorder
    pkgs.ffmpeg
  ];

  shellHook = ''
    if [ ! -d .venv ]; then
      python3 -m venv .venv
    fi
    source .venv/bin/activate
  '';
}
