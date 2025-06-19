{pkgs, ...}:
{
  users.users.maxlang = {
    isNormalUser = true;
    description = "Max Langhorst";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    packages = with pkgs; [
      # Desktop Environment Stuff
      waybar 
      dunst #notifications
      libnotify #notifications
      rofi-wayland #launcher
      rofimoji
      rofi-calc
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
    ];
  };
}