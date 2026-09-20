{ lib, writeShellApplication, hyprland, ghostty, jq }:

writeShellApplication {
  name = "popup-launch";

  runtimeInputs = [
    hyprland
    ghostty
    jq
  ];

  text = builtins.readFile ./popup-launch.sh;

  meta = {
    description = "Open a centered terminal popup over the current Hyprland workspace";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "popup-launch";
  };
}
