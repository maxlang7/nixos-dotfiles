{ pkgs, config, ... }:

let
  # A small wrapper script to bridge the portal and yazi
  yazi-picker = pkgs.writeShellScriptBin "yazi-picker" ''
    # The portal passes the output path as the first argument
    out=$1
    shift
    # Run yazi. When a file is selected, it writes the path to $out
    ${pkgs.yazi}/bin/yazi --chooser-file="$out" "$@"
  '';
in
{
  home.packages = [
    pkgs.xdg-desktop-portal-termfilechooser
    yazi-picker
  ];

  # Configure the portal backend
  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [chooser]
    # We launch the terminal with a specific class "yazi-picker" for Hyprland targeting
    cmd=${pkgs.ghostty}/bin/foot --class "yazi-picker" -e ${yazi-picker}/bin/yazi-picker
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
