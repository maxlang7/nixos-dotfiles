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
        # Local patches carried on top of unstable. Each entry is a package we
        # have an upstream PR open for — delete it once the fix lands and the
        # nixpkgs bump reaches us. Patch files live in artifacts/patches/.
        overlays = [
          inputs.brave.overlays.default
          (final: prev: {
            # Use OpenAI's complete release package to avoid a large Rust build.
            codex = prev.stdenvNoCC.mkDerivation {
              pname = "codex";
              version = "0.167.0";
              src = prev.fetchurl {
                url = "https://github.com/openai/codex/releases/download/rust-v0.167.0/codex-package-x86_64-unknown-linux-musl.tar.gz";
                sha256 = "3bbf75e83de6b58aed28f2cf6e33ad423ec31fd4700a1457b94be557ea5a7c6e";
              };
              sourceRoot = ".";
              nativeBuildInputs = [ prev.autoPatchelfHook ];
              buildInputs = [ prev.stdenv.cc.cc.lib prev.alsa-lib ];
              dontConfigure = true;
              dontBuild = true;
              dontStrip = true;
              installPhase = ''
                runHook preInstall
                mkdir -p $out
                cp -a bin codex-package.json codex-path codex-resources $out/
                runHook postInstall
              '';
              doInstallCheck = true;
              installCheckPhase = ''
                $out/bin/codex --version
                $out/bin/codex-code-mode-host --help >/dev/null
              '';
              meta = prev.codex.meta;
            };
            t3code = prev.t3code.override {
              t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (finalAttrs: old: {
                # Pin the current stable release without updating unrelated packages.
                version = "0.1.7";
                src = prev.fetchFromGitHub {
                  owner = "pingdotgg";
                  repo = "t3code";
                  tag = "v${finalAttrs.version}";
                  hash = "sha256-oQLmDCDuJPNBsf8MHMD2xhMq+CF6L836/PQesM91Clw=";
                };
                pnpmDeps = prev.fetchPnpmDeps {
                  pnpm = prev.pnpm_12;
                  inherit (finalAttrs) pname version src pnpmWorkspaces;
                  fetcherVersion = 5;
                  hash = "sha256-o3RujO4r84ncdp75XE6wiiwhbD9DLmZDXgYHjpLCGMA=";
                };
                patches = (old.patches or []) ++ [
                  ./artifacts/patches/t3code-shortcuts.patch
                ];
              });
            };
            # Home "feature carousel" painted torn fragments of previously shown
            # album art around each cover (drop-shadow filter + GPU raster).
            feishin = prev.feishin.overrideAttrs (old: {
              patches = (old.patches or []) ++ [
                ./artifacts/patches/feishin-carousel-shadow.patch
              ];
            });
          })
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
          #spicetify-nix.nixosModules
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit pkgs-unstable inputs user hostName; };
              users.${user} = { imports = homeModules; };
            };
          }
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
          # Pause the old Mac/BlueBubbles bridge while retaining its data.
          ({ lib, ... }: {
            systemd.services.imessage-bridge.enable = lib.mkForce false;
            systemd.services.imessage-bridge-watchdog.enable = lib.mkForce false;
            systemd.timers.imessage-bridge-watchdog.enable = lib.mkForce false;
          })
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
