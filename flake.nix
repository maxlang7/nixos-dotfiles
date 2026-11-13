{
  description = "Max's NixOS configuration";

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    crane.url = "github:ipetkov/crane";

    # Brave was removed from nixpkgs; use the signed upstream binary package.
    brave = {
      url = "github:cmm/brave-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # ── secrets (sops-nix) — comment these two lines to fully disable ──
    # (also comment ./sops.nix in modules/nixos/maxlang.nix)
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
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
    user = "maxlang";
    mkNixosSystem = { hostName, modules, homeModules }: let
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
        # Local package pins and patches. Patch files live in artifacts/patches/.
        overlays = [
          inputs.brave.overlays.default
          (import ./overlays/desktop.nix)
        ];
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
          ({ config, pkgs, ... }: let
            home = config.home-manager.users.${user};
            # Use the same packages and rendered settings as the configured apps.
            userApps = import ./packages/user-apps.nix {
              inherit pkgs inputs;
              yazi = home.programs.yazi.package;
              notificationConfig = home.xdg.configFile."swaync/config.json".source;
              notificationStyle = home.services.swaync.style;
            };
          in {
            _module.args.userApps = userApps;
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit pkgs-unstable inputs user hostName userApps; };
              users.${user} = { imports = homeModules; };
            };
          })
        ];
      };
  in {
    packages.${system}.calendar-tui = let
      pkgs = import nixpkgs { inherit system; };
    in pkgs.callPackage ./packages/calendar-tui { craneLib = inputs.crane.mkLib pkgs; };

    nixosConfigurations = {
      Aragorn = mkNixosSystem {
        hostName = "Aragorn";
        modules = [
          ./hosts/Aragorn/configuration.nix
          ./modules/nixos/blueferry.nix
          ./modules/nixos/blueferry-beeper.nix
        ];
        homeModules = [ ./hosts/Aragorn/home.nix ./modules/home_manager/blueferry.nix ./modules/home_manager/blueferry-beeper.nix ];
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
