{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    #unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    #home-manager = {
    #  url = "github:nix-community/home-manager";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};
  };

  outputs = { self, nixpkgs, ...}@inputs: {
    # One of these for each host
    nixosConfigurations = {
      Aragorn = nixpkgs.lib.nixosSystem {
	      specialArgs = {inherit inputs;};
        modules = [
          ./hosts/Aragorn/configuration.nix
          #inputs.home-manager.nixosModules.default
        ];
      };
  };
    /*
    some_other_host = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      modules = [
        ./hosts/Aragorn/configuration.nix
        #inputs.home-manager.nixosModules.default
      ];
    };
    */
  };
}
