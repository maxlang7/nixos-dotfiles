{ pkgs, config, ... }:

let
  # Script matching the 5-arg signature xdg-desktop-portal-termfilechooser uses:
  # $1=multiple $2=directory $3=save $4=starting_path $5=output_file
  yazi-picker-wrapper = pkgs.writeShellScriptBin "yazi-picker-wrapper" ''
    multiple="$1"
    directory="$2"
    save="$3"
    path="$4"
    out="$5"
    export YAZI_CONFIG_HOME="$HOME/.config/yazi"
    if [ "$directory" = "1" ]; then
      ${pkgs.ghostty}/bin/ghostty --class=yazi-picker --title=termfilechooser -e ${pkgs.yazi}/bin/yazi --chooser-file="$out" --cwd-file="$out" "$path"
    else
      ${pkgs.ghostty}/bin/ghostty --class=yazi-picker --title=termfilechooser -e ${pkgs.yazi}/bin/yazi --chooser-file="$out" "$path"
    fi
  '';
in
{
  home.packages = [
    pkgs.xdg-desktop-portal-termfilechooser
    yazi-picker-wrapper
  ];

  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${yazi-picker-wrapper}/bin/yazi-picker-wrapper
  '';

  # Ensure the portal knows to use termfilechooser
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-termfilechooser ];
    config = {
      common = {
        default = [ "gtk" ]; # Keep gtk as fallback
        "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
      };
    };
  };
}
