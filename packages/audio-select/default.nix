{
  lib,
  writeShellApplication,
  python3,
  wireplumber,
  pipewire,
  ffmpeg,
  networkmanager,
  bluez,
  systemd,
  hyprland,
  hyprlock,
}:

writeShellApplication {
  name = "audio-select";

  runtimeInputs = [
    python3
    wireplumber
    pipewire
    ffmpeg
    networkmanager
    bluez
    systemd
    hyprland
    hyprlock
  ];

  text = ''
    exec python3 ${./audio-select.py} "$@"
  '';

  meta = {
    description = "Gruvbox terminal controls for audio, networking, Bluetooth, and power";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "audio-select";
  };
}
