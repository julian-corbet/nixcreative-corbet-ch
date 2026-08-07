#
# nixcreative — creator tooling, declared by intention:
# audio editors, image editors, video editors, and studio extras.
#
# This module is platform-neutral and only computes what a host wants.
# NixOS/system-manager backends consume the computed lists.
#
{ config, lib, ... }:
let
  cfg = config.nixcreative;
  cat = import ../lib/creative.nix { };

  mkGroup = name: table: lib.mkOption {
    type = lib.types.listOf (lib.types.enum (lib.attrNames table));
    default = [ ];
    description = "Which ${name}. Available: ${lib.concatStringsSep ", " (lib.attrNames table)}.";
  };

  selected = lib.flatten [
    (map (k: cat.audio.${k}) cfg.audio)
    (map (k: cat.image.${k}) cfg.image)
    (map (k: cat.video.${k}) cfg.video)
  ];
in
{
  options.nixcreative = {
    audio = mkGroup "audio creative tools" cat.audio;
    image = mkGroup "image editing and raster tools" cat.image;
    video = mkGroup "video editing and timeline tools" cat.video;

    selected = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      internal = true;
      description = "Resolved catalogue entries for every selected audio/image/video tool.";
    };

    archPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Host-facing package names for pacman.

        Pair with:

          nixarch.packages.pacman = config.nixcreative.archPackages;

        AUR-only entries (if any) stay out of this list and go in `aurPackages`.
      '';
    };

    aurPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Host-facing package names that live in AUR.
        Wire to:

          nixarch.packages.aur = config.nixcreative.aurPackages;

        With no aur reconciler configured for AUR, these are a warning-only gap.
      '';
    };

    nixosPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Dotted nixpkgs names for declarative visibility; consumers should not assume this list
        is fully installable without resolution.
      '';
    };

    unavailableOnNixos = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Selected tools with no nixpkgs equivalent.";
    };
  };

  config = {
    nixcreative.selected = selected;
    nixcreative.archPackages = lib.unique (map (t: t.arch) (lib.filter (t: !(t.aur or false)) selected));
    nixcreative.aurPackages = lib.unique (map (t: t.arch) (lib.filter (t: t.aur or false) selected));
    nixcreative.nixosPackages = lib.unique (map (t: t.nixpkgs) (lib.filter (t: t.nixpkgs != null) selected));
    nixcreative.unavailableOnNixos = lib.unique (map (t: t.arch) (lib.filter (t: t.nixpkgs == null) selected));
  };
}
