{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = [ pkgs.go pkgs.python3 pkgs.dbus pkgs.pkg-config ];
  shellHook = ''
    if [ ! -d .venv ]; then python -m venv .venv; fi
    source .venv/bin/activate
    python -m pip install -r requirements-dev.txt
    export GOTOOLCHAIN=local
  '';
}
