{config, pkgs, inputs, ...}:
{
  imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];
  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

  services.minecraft-servers = {
      enable = true;
      eula = true;
      openFirewall = true;
      servers.friends = {
        enable = true;
        autoStart = true;
        serverProperties = {
          difficulty = "hard";
          gamemode = "survival";
          motd = "RIP Dig Bick Sus but we in a new era now";
          white-list = "true";
          #level-name = "world"
        };
        package = pkgs.fabricServers.fabric;
        operators = {
          Fqbl3d = "d8e55646-6686-410f-8ce6-098798a22f01";
        };
        whitelist = {
            JRX2015 =  "ee55951a-330b-48ae-a3f3-d701a3618b7d";
            Kosmo_Z =  "614858f1-b52c-47c0-b46d-900f43eb0949";
            zpalindrome =  "a2396ed5-0942-4f79-a9e4-9a80582e11fd";
            Xcalibur9720 =  "5b90985a-9da0-40ba-b593-1a0c1dbacce5";
            PlataoUII =  "6bec4248-5db8-47a3-a6bb-fa54ac6a44ad";
            UV_Cataztrophe =  "2b316ed9-212b-4439-9bd5-2c878f5f7b68";
            siravitnemo =  "6596675d-34fa-49c2-bc93-1c8b8a604f06";
        };
        symlinks = {
          mods = pkgs.linkFarmFromDrvs "mods" (
            builtins.attrValues {
              double_doors= pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/JrvR9OHr/versions/rGbyCR52/doubledoors-1.21.5-6.2.jar";
                sha512 = "2713b0c1a81f2e168de034fb81b6ad177bf1ec69100819135ba0c151cdc1514dfc978ee468c1b1ea5dab3abe48d0515297bce27938423b35f4aa8f16defeb5d2";
              };
            }
          );
        };
      };
    };
}