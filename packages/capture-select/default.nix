{ lib, writeShellApplication, python3, ffmpeg }:

writeShellApplication {
  name = "capture-select";

  runtimeInputs = [
    python3
    ffmpeg
  ];

  text = ''
    exec python3 ${./capture-select.py} "$@"
  '';

  meta = {
    description = "Gruvbox terminal interface for screen and selective audio recording";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "capture-select";
  };
}
