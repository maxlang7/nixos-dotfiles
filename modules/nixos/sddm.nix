{config, pkgs, ...}:
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "where_is_my_sddm_theme";
    package = pkgs.kdePackages.sddm;
    extraPackages = [ 
      pkgs.kdePackages.qt5compat
    ];
  };
  environment.systemPackages = with pkgs; [
    (where-is-my-sddm-theme.override {
          themeConfig.General = {
            background = toString ../../images/abbey_broad.jpeg;
	          backgroundMode = "aspect";
            passwordCursorColor = "#00FF41";
            passwordTextColor = "#00FF41";
            passwordAllowEmpty = true; 
            basicTextColor = "#00FF41";
          };
    })
  ];
}