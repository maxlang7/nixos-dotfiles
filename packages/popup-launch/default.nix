{ lib, writeShellApplication, hyprland, ghostty }:

writeShellApplication {
  name = "popup-launch";

  runtimeInputs = [
    hyprland
    ghostty
  ];

  text = builtins.readFile ./popup-launch.sh;

  meta = {
    description = "Open a centered terminal popup over the current Hyprland workspace";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "popup-launch";
  };
}
