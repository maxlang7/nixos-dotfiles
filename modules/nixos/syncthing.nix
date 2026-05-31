{user, ...}:
{

  services.syncthing = {
    enable = true;
    user = "${user}";
    dataDir = "/home/${user}/Music/navidrome";
    configDir = "/home/${user}/.config/syncthing";
    openDefaultPorts = true; # Opens firewall ports 22000/TCP/UDP and 21027/UDP

    overrideDevices = true;     # Overrides any devices added manually via WebUI
    overrideFolders = true;     # Overrides any folders added manually via WebUI

    settings = {
      devices = {
        "Up" = { id = "5UMGQQ6-3N3DXSU-F4PI5Z6-ON6SHAP-ACDIVYH-FURDVR4-X5V7ED6-TOUQJAS"; };
      };
      folders = {
        "navidrome" = {
          path = "/home/${user}/Music/navidrome"; # Path to your laptop music folder
          devices = [ "Up" ];         # Share this folder with the server
          versioning = {
            type = "simple";
            params = { keep = "5"; };        # Keeps 5 old versions of modified/deleted tracks
          };
        };
      };
    };
  };

  # Force Syncthing to skip creating its annoying default "~/Sync" folder
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

}
