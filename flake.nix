{
  description = "nixcreative — declarative creative tool selection for creation workflows (DAW, vector, raster, 3D).";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    in
    {
      # Platform-neutral policy and package catalogue.
      nixosModules.nixcreative = ./modules/nixcreative.nix;
      homeManagerModules.nixcreative = ./home/nixcreative.nix;
      homeManagerModules.default = ./home/nixcreative.nix;
      homeManagerModules.install = ./home/nixcreative.nix;

      # Install plane: NixOS host packages.
      nixosModules.default = ./modules/nixos.nix;
      nixosModules.install = ./modules/nixos.nix;

      # Arch/CachyOS plane: publish `nixcreative.archPackages` / `.aurPackages` into host reconciler.
      systemManagerModules.nixcreative = ./modules/arch.nix;
      systemManagerModules.default = ./modules/arch.nix;
      systemManagerModules.install = ./modules/arch.nix;

      # Expose the catalogue for introspection, docs, and checks.
      lib.catalogue = import ./lib/creative.nix { };

      checks = forAllSystems (system: {
        catalogue-eval = import ./checks/catalogue-eval.nix {
          pkgs = nixpkgs.legacyPackages.${system};
        };
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);
    };
}
