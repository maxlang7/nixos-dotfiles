{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = [
    pkgs.hyprland
    pkgs.ghostty
    pkgs.shellcheck
  ];
}
