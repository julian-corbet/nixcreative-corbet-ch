# nixcreative

`nixcreative` declares creative tooling intentionally:

- `audio`: editors/composition tools
- `image`: raster/vector editing tools
- `video`: editing/compositing/conversion tools

This repo is for installation intent only (package selection). It does not own app runtime
configuration.

## Outputs

- `nixosModules.nixcreative` / `.default` / `.install`
  - `modules/nixcreative.nix` → option model and resolved package lists
  - `modules/nixos.nix` → installs `environment.systemPackages`
- `systemManagerModules.nixcreative` / `.default` / `.install`
  - `modules/nixcreative.nix` → option model
  - `modules/arch.nix` → exports `archPackages` / `aurPackages`
- `lib.catalogue`
  - the curated package table
- `checks.catalogue-eval`
  - verifies option enums + grouping behaviour under Nix evaluation

## Example

```nix
{
  imports = [ inputs.nixcreative.nixosModules.nixcreative ];
  nixcreative = {
    audio = [ "ardour" "audacity" ];
    image = [ "gimp" "inkscape" ];
    video = [ "kdenlive" "blender" ];
  };
}
```

## Arch/CachyOS wiring

```nix
{
  imports = [ inputs.nixcreative.systemManagerModules.nixcreative ];

  nixcreative = {
    audio = [ "ardour" ];
    image = [ "krita" ];
  };

  nixarch.packages = {
    pacman = config.nixcreative.archPackages;
    aur = config.nixcreative.aurPackages;
  };
}
```

## Why this shape

This follows the same module family style used by adjacent projects:
platform-neutral option module (`modules/nixcreative.nix`) plus platform-specific installers
(`modules/nixos.nix`, `modules/arch.nix`) to keep policy and deployment boundaries clean.

## Status

Initial scaffold with a stable catalogue-backed split for creator applications:

- audio: `audacity`, `ardour`, `lmms`, `reaper`, `qjackctl`
- image: `gimp`, `darktable`, `krita`, `inkscape`, `rawtherapee`
- video: `kdenlive`, `blender`, `shotcut`, `ffmpeg`

## License

[MIT License](LICENSE) © 2026 Julian Corbet
