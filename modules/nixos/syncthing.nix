{user, ...}:
{
  services.syncthing = {
    enable = true;
    user = "${user}";
    dataDir = "/home/${user}/";
    configDir = "/home/${user}/.config/syncthing";
    openDefaultPorts = true;
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = {
        "Up" = { id = "5UMGQQ6-3N3DXSU-F4PI5Z6-ON6SHAP-ACDIVYH-FURDVR4-X5V7ED6-TOUQJAS"; };
      };
      folders = {
        "navidrome" = {
          path = "/home/${user}/Music/navidrome";
          devices = [ "Up" ];
          versioning = {
            type = "simple";
            params = { keep = "5"; };
          };
        };
        "books" = {
          path = "/home/${user}/Documents/books";
          devices = [ "Up" ];
          versioning = {
            type = "simple";
            params = { keep = "5"; };
          };
        };
      };
    };
  };
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";
}
