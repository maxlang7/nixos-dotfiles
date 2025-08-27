{config, pkgs, pkgs-unstable, ...}:
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "where_is_my_sddm_theme";
    package = pkgs.kdePackages.sddm;
    settings = {
      # Autologin = {
      #   Session = "hyprland.desktop";
      #   User = "maxlang";
      # };
      General = {
        DefaultSession="hyprland.desktop";
      };
    };
    extraPackages = [ 
      pkgs.kdePackages.qt5compat
    ];
  };
  environment.systemPackages = with pkgs; [
    (where-is-my-sddm-theme.override {
          themeConfig.General = {
            background = toString ../../images/abbey_broad.jpeg;
	          backgroundMode = "aspect";
            passwordCursorColor = "#98971a";
            passwordTextColor = "#98971a";
            passwordAllowEmpty = true; 
            basicTextColor = "#98971a";
          };
    })
  ];
}