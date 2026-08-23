{ config, pkgs, lib, ... }:
# ReGreet — a small GTK4 greeter running inside cage, driven by greetd.
#
#  Why this and not sddm: no Qt/QML theme engine to break on updates, and the
#  whole thing is ~60 lines of declarative config instead of a themed package
#  override. `programs.regreet.enable` turns on greetd itself and writes the
#  default_session command (cage -> regreet), so there is no greetd block here.
#
#  Session list comes from services.displayManager.sessionPackages, which
#  programs.hyprland populates — hyprland.desktop shows up automatically.
{
  programs.regreet = {
    enable = true;

    settings = {
      background = {
        # Nix path -> copied into the store, so the greeter (user `greeter`)
        # can read it. Do NOT point at a file under /home; greeter can't read it.
        path = ../../images/abbey_broad.jpeg;
        fit = "Cover";
      };

      GTK.application_prefer_dark_theme = true;

      appearance.greeting_msg = "Welcome back.";

      commands = {
        reboot = [ "systemctl" "reboot" ];
        poweroff = [ "systemctl" "poweroff" ];
      };

      widget.clock = {
        format = "%a %b %-d   %H:%M";
        resolution = "1s";
        label_width = 220;
      };
    };

    # Matches the desktop: hyprland.conf sets HYPRCURSOR_THEME=Bibata-Original-Ice.
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Original-Ice";
    };

    theme = {
      package = pkgs.gruvbox-gtk-theme;
      name = "Gruvbox-Dark";
    };

    iconTheme = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
    };

    font = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
      # 2256x1504 on a 13" panel: cage renders at native res with no scaling,
      # so the font size is the only knob that makes the card readable.
      size = 16;
    };
  };

  # regreet finds sessions via XDG_DATA_DIRS, but that is only exported through
  # PAM/profile — a systemd system service never sees it, so the greeter would
  # fall back to /usr/share/wayland-sessions and offer no sessions at all.
  systemd.services.greetd.environment.XDG_DATA_DIRS =
    "${config.services.displayManager.sessionData.desktops}/share";

  # Preselect Hyprland (the old sddm module did this via General.DefaultSession).
  services.displayManager.defaultSession = lib.mkDefault "hyprland";
}
