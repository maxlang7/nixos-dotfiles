{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = [
    pkgs.python3
    pkgs.wireplumber
    pkgs.pipewire
    pkgs.ffmpeg
    pkgs.networkmanager
    pkgs.bluez
    pkgs.systemd
    pkgs.hyprland
    pkgs.hyprlock
  ];

  shellHook = ''
    if [ ! -d .venv ]; then
      python3 -m venv .venv
    fi
    source .venv/bin/activate
  '';
}
