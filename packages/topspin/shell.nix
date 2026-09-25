{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = [
    pkgs.wineWow64Packages.waylandFull
    pkgs.winetricks
    pkgs.shellcheck
  ];
}
