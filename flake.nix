{
  description = "Max's NixOS configuration";

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    # ── secrets (sops-nix) — comment these two lines to fully disable ──
    # (also comment ./sops.nix in modules/nixos/maxlang.nix)
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    # spicetify-nix.url = "github:Gerg-L/spicetify-nix";

    claude-cowork-linux.url = "github:johnzfitch/claude-cowork-linux";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    ...
  }: let
    system = "x86_64-linux";
    user = "maxlang";
    mkNixosSystem = { hostName, modules, homeModules }: let
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit pkgs-unstable inputs user hostName;
        };
        modules = modules ++ [
          home-manager.nixosModules.home-manager
          # sops-nix is pulled in by modules/nixos/sops.nix (self-contained,
          # so disabling that one import cleanly disables secrets).
          #spicetify-nix.nixosModules
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit pkgs-unstable user hostName; };
              users.${user} = { imports = homeModules; };
            };
          }
        ];
      };
  in {
    nixosConfigurations = {
      Aragorn = mkNixosSystem {
        hostName = "Aragorn";
        modules = [ ./hosts/Aragorn/configuration.nix ];
        homeModules = [ ./hosts/Aragorn/home.nix ];
      };
      Gandalf = mkNixosSystem {
        hostName = "Gandalf";
        modules = [ ./hosts/Gandalf/configuration.nix ];
        homeModules = [ ./hosts/Gandalf/home.nix ];
      };
      simple = mkNixosSystem {
        hostName = "simple";
        modules = [ ./hosts/simple/configuration.nix ];
        homeModules = [ ./hosts/simple/home.nix ];
      };
    };
  };
}
