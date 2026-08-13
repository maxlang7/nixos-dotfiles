{ pkgs, config, ... }:

let
  # Use the SAME yazi the user actually configured (programs.yazi.package, i.e.
  # pkgs-unstable.yazi) rather than `pkgs.yazi`. Those had drifted two releases
  # apart — stable 25.5.31 here vs unstable 26.5.6 everywhere else — so the
  # picker was the only yazi on the system reading ~/.config/yazi with an older
  # parser. Pinning it to one source of truth keeps that from recurring.
  yazi = config.programs.yazi.package;

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
    # `class` must be a valid GTK application ID (reverse-DNS, at least one
    # dot). "yazi-picker" is not, so Ghostty logged "invalid 'class' in config,
    # ignoring" and the window kept the default app-id. Nothing targets the
    # class today — the Hyprland rules in hyprland.conf all match
    # `title:termfilechooser` — but a silently-dropped setting is worse than a
    # correct one.
    if [ "$directory" = "1" ]; then
      ${pkgs.ghostty}/bin/ghostty --class=com.yazi.picker --title=termfilechooser \
        -e "${yazi}/bin/yazi --chooser-file=$out_q --cwd-file=$out_q $path_q"
    else
      ${pkgs.ghostty}/bin/ghostty --class=com.yazi.picker --title=termfilechooser \
        -e "${yazi}/bin/yazi --chooser-file=$out_q $path_q"
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
