{ pkgs, user, ... }:
{
  imports =
    [
      ./personal-packages.nix
      ./user.nix
      ./desktop_environment_apps.nix
      ./navidrome.nix
      ./wireguard.nix
      ./syncthing.nix
      ./autoupgrade.nix
      ./sops.nix # secrets — comment to disable (see header in sops.nix)
    ];
  boot.loader.timeout = 0;

  programs.dconf.profiles.user.databases = [{
     settings = {
       "org/gnome/desktop/interface".color-scheme = "prefer-dark";
       "org/gnome/desktop/sound" = {
         event-sounds = false;
         input-feedback-sounds = false;
       };
     };
   }];

  nix.settings.download-buffer-size = 524288000;

  environment.variables.EDITOR = "zeditor";

  programs.steam.enable = true;
  programs.gpu-screen-recorder.enable = true;
}
