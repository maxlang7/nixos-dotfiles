{ pkgs, user, userApps, ... }: {
  users.users.${user}.packages = with pkgs; [
    wtype taskwarrior3 taskwarrior-tui xdg-desktop-portal-termfilechooser
  ] ++ (with userApps; [
    calendarTui topspin blueferry bridge waybar-bluetooth
    control yazi-picker-wrapper t3-settings-sync
  ]);
}
