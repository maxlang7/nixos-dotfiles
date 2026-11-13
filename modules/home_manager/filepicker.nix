{ pkgs, userApps, ... }:
let
  yazi-picker-wrapper = userApps.yazi-picker-wrapper;
in
{
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
