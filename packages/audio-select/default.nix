{ lib, writeShellApplication, python3, wireplumber, pipewire, ffmpeg }:

writeShellApplication {
  name = "audio-select";

  runtimeInputs = [
    python3
    wireplumber
    pipewire
    ffmpeg
  ];

  text = ''
    exec python3 ${./audio-select.py} "$@"
  '';

  meta = {
    description = "Small terminal selector and test utility for PipeWire devices";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "audio-select";
  };
}
