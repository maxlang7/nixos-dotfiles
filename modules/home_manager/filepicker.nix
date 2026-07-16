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
    out_q=$(printf '%q' "$out")
    path_q=$(printf '%q' "$path")
    if [ "$directory" = "1" ]; then
      ${pkgs.ghostty}/bin/ghostty --class=yazi-picker --title=termfilechooser \
        -e "${pkgs.yazi}/bin/yazi --chooser-file=$out_q --cwd-file=$out_q $path_q"
    else
      ${pkgs.ghostty}/bin/ghostty --class=yazi-picker --title=termfilechooser \
        -e "${pkgs.yazi}/bin/yazi --chooser-file=$out_q $path_q"
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

  # Ensure the portal knows to use termfilechooser.
  # NOTE: home-manager's xdg.portal takes over the user session's portal
  # environment (NIX_XDG_DESKTOP_PORTAL_DIR), so its extraPortals list REPLACES
  # the system-level one for this user. Every backend the session needs must be
  # listed here — including hyprland (ScreenCast/Screenshot, needed for screen
  # sharing in Vesktop/Zoom) and gtk (Settings/Notification/etc.). Omitting
  # hyprland is what broke screen sharing ("hyprland.portal is unrecognized").
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-termfilechooser
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        # hyprland first so ScreenCast/Screenshot route to it; gtk as fallback.
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
      };
    };
  };
}
