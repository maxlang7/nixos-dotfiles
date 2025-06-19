{
  description = "NixOS configuration of Ryan Yin";

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    ...
  }: let
    system = "x86_64-linux";

    mkNixosSystem = { modules, homeModules }: let
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit pkgs-unstable inputs;
        };
        modules = modules ++ [
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit pkgs-unstable; };
              users.maxlang = { imports = homeModules; };
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
    };
  };
}