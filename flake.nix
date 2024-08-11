{
  description = "ogmios";

  inputs = {
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    CHaP = {
      url = "github:input-output-hk/cardano-haskell-packages?ref=repo";
      flake = false;
    };
    iohk-nix.url = "github:input-output-hk/iohk-nix";
  };

  outputs = { self, nixpkgs, haskell-nix, iohk-nix, CHaP, ... }@inputs:
    let
      systems = [
        "x86_64-linux"
        # "x86_64-darwin"
        # "aarch64-linux"
        # "aarch64-darwin"
      ];
      perSystem = nixpkgs.lib.genAttrs systems;
      pkgs = perSystem (system: import nixpkgs {
        inherit system;
        overlays = [
          haskell-nix.overlay
          iohk-nix.overlays.crypto
          iohk-nix.overlays.haskell-nix-crypto
        ];
        inherit (haskell-nix) config;
      });
      project = perSystem (system: pkgs.${system}.haskell-nix.project {
        compiler-nix-name = "ghc96";
        projectFileName = "cabal.project";
        src = nixpkgs.lib.cleanSourceWith {
          name = "ogmios-src";
          src = ./server;
          filter = path: type:
            builtins.all (x: x) [
              (baseNameOf path != "package.yaml")
            ];
        };
        inputMap = { "https://input-output-hk.github.io/cardano-haskell-packages" = CHaP; };
        modules = [
          { packages.ogmios.flags.production = true; }
        ];
      });
      flake = perSystem (system: project.${system}.flake { });
    in {
      packages = perSystem (system: {
        ogmios = flake.${system}.packages."ogmios:exe:ogmios";
        default = self.packages.${system}.ogmios;
      });
      nixosModules.ogmios = { pkgs, lib, ... }: {
        imports = [ ./ogmios-nixos-module.nix ];
        services.ogmios.package = lib.mkOptionDefault self.packages.${pkgs.system}.ogmios;
      };
      # herculesCI.ciSystems = [ "x86_64-linux" ];
    };
}
