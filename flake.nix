{
  description = "NixOS configuration of Ryan Yin";

  inputs = {
    # Default to the nixos-unstable branch
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

    # Latest stable branch of nixpkgs, used for version rollback
    # The current latest version is 24.11
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # You can also use a specific git commit hash to lock the version
    #nixpkgs-fd40cef8d.url = "github:nixos/nixpkgs/fd40cef8d797670e203a27a91e4b8e6decf0b90c";
  };

  outputs = inputs@{
    self,
    nixpkgs,
    nixpkgs-unstable,
    #nixpkgs-fd40cef8d,
    ...
  }: {
    nixosConfigurations = {
      my-nixos = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        # The `specialArgs` parameter passes the
        # non-default nixpkgs instances to other nix modules
        specialArgs = {
          # To use packages from nixpkgs-stable,
          # we configure some parameters for it first
          pkgs-unstable = import nixpkgs-unstable {
            # Refer to the `system` parameter from
            # the outer scope recursively
            inherit system;
            # To use Chrome, we need to allow the
            # installation of non-free software.
            config.allowUnfree = true;
          };
        #   pkgs-fd40cef8d = import nixpkgs-fd40cef8d {
        #     inherit system;
        #     config.allowUnfree = true;
        #   };
        # };

        # modules = [
        #   ./hosts/my-nixos

        #   # Omit other configurations...
        # ];
      };
    };
  };
};
}