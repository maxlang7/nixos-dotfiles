{
  description = "NixOS configuration of Ryan Yin";

  inputs = {
    # Default to the nixos-unstable branch
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Latest stable branch of nixpkgs, used for version rollback
    # The current latest version is 24.11
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

    # You can also use a specific git commit hash to lock the version
    # nixpkgs-fd40cef8d.url = "github:nixos/nixpkgs/fd40cef8d797670e203a27a91e4b8e6decf0b90c";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    #nixpkgs-fd40cef8d,
    ...
  }:
    let
      system = "x86_64-linux";

      # Function to create a NixOS system configuration
      mkNixosSystem = { hostName, modules, homeModules }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
            home-manager = home-manager.lib.homeManagerConfiguration {
              pkgs = nixpkgs.legacyPackages.${system};
              modules = homeModules; # Your Home Manager modules
            };
          };
          modules = modules;
        };
    in
    {
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
