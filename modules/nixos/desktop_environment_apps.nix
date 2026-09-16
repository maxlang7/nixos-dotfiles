{pkgs, user, hostName, lib, ...}:
{
  users.users.${user}.packages = with pkgs; [
      # Desktop Environment Stuff
      waybar
      libnotify #notifications
      rofi #launcher — `rofi-wayland` was merged into `rofi` in 25.11
      rofimoji
      rofi-power-menu
      rofi-bluetooth
      bibata-cursors
      hyprcursor
      brightnessctl
      playerctl
      hyprpaper
      hyprlock
      hypridle
      wlsunset
      pavucontrol
      trashy
      powertop
      batsignal
      grimblast #Screenshot
    ] ++ lib.optionals (hostName != "Aragorn") [ pkgs.dunst ];
}
