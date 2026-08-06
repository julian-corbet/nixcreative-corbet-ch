# Evaluates modules/nixcreative.nix and verifies catalogue wiring for audio/image/video selections.
{ pkgs, lib ? pkgs.lib }:
let
  evalWith = selection: (lib.evalModules {
    modules = [ ../modules/nixcreative.nix selection ];
  }).config.nixcreative;

  fullAudio = evalWith { audio = [ "audacity" "ardour" ]; };
  fullImage = evalWith { image = [ "gimp" "krita" ]; };
  fullVideo = evalWith { video = [ "kdenlive" "blender" "ffmpeg" ]; };
  all = evalWith {
    audio = [ "audacity" ];
    image = [ "gimp" ];
    video = [ "kdenlive" ];
  };

  has = list: item: lib.elem item list;

  results = {
    "empty selection resolves to no selected tool" =
      (evalWith { }).selected == [ ];

    "audio selection is expanded, no AUR by default" =
      fullAudio.archPackages == [ "audacity" "ardour" ] && fullAudio.aurPackages == [ ];

    "audio group + availability summary looks right" =
      fullAudio.nixosPackages == [ "audacity" "ardour" ]
      && fullAudio.unavailableOnNixos == [ ];

    "image selection resolves the exact names" =
      fullImage.archPackages == [ "gimp" "krita" ]
      && fullImage.unavailableOnNixos == [ ];

    "video selection resolves the exact names" =
      fullVideo.archPackages == [ "kdenlive" "blender" "ffmpeg" ]
      && fullVideo.unavailableOnNixos == [ ];

    "groups compose into one selected list" =
      lib.length all.selected == 3;

    "arch and aur lists never overlap" =
      lib.intersectLists all.archPackages all.aurPackages == [ ];

    "bad audio name is rejected at eval time" =
      (builtins.tryEval (builtins.deepSeq (evalWith { audio = [ "audioslicer" ]; }).audio true)).success == false;

    "bad image name is rejected at eval time" =
      (builtins.tryEval (builtins.deepSeq (evalWith { image = [ "photoshop" ]; }).image true)).success == false;

    "bad video name is rejected at eval time" =
      (builtins.tryEval (builtins.deepSeq (evalWith { video = [ "finalcut" ]; }).video true)).success == false;
  };

  failed = lib.attrNames (lib.filterAttrs (_: passed: !passed) results);
in
if failed == [ ] then
  pkgs.emptyFile
else
  throw ''
    nixcreative: catalogue-eval check failed:
    ${lib.concatMapStringsSep "\n" (f: "  - ${f}") failed}
  ''
