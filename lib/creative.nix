let
  inherit (builtins) mapAttrs;
in
{
  # ── DAW ─────────────────────────────────────────────────────────────────────────────────────
  #
  # DELIBERATELY EMPTY. A digital audio workstation belongs HERE and not in nixrecord, and the
  # reasoning is the one this repo's gate already states: a DAW authors material whose result is not
  # specified before the work starts -- two people at the same session file produce two different
  # records -- whereas nixrecord captures an event that happened. Recording a take is capture;
  # arranging, mixing and mastering it is not.
  #
  # The second reason is structural, and it is why this must not drift into nixrecord later: nixrecord
  # is single-host BECAUSE OF AN ENCODER (only one machine in this estate has an AV1 hardware
  # encoder). Anything filed there inherits that constraint permanently. Authoring is not
  # encoder-bound, so binding a DAW to one machine would be an accident of hardware, not a decision.
  #
  # The operator has ruled that NO DAW is wanted at present -- Ardour, Reaper and LMMS were all
  # considered and declined. The group exists so that the ruling is recorded where the next addition
  # would be made, rather than argued again from scratch. Adding one here needs no new group and no
  # new boundary; it needs a decision.
  daw = { };

  audio = {
    audacity = {
      arch = "audacity";
      nixpkgs = "audacity";
      description = "Multitrack audio editor with practical day-to-day tooling.";
    };

    ardour = {
      arch = "ardour";
      nixpkgs = "ardour";
      description = "Professional digital audio workstation and mixer workflow.";
    };

    lmms = {
      arch = "lmms";
      nixpkgs = "lmms";
      description = "Loop-based music production and composition.";
    };

    reaper = {
      arch = "reaper-bin";
      nixpkgs = "reaper";
      aur = true;
      description = "Proprietary DAW from Cockos (nixpkgs package varies by host availability).";
    };

    qjackctl = {
      arch = "qjackctl";
      nixpkgs = "qjackctl";
      description = "JACK graph control for audio routing/latency workflows.";
    };
  };

  image = {
    gimp = {
      arch = "gimp";
      nixpkgs = "gimp";
      description = "Core bitmap editor with compositing and retouching workflows.";
    };

    darktable = {
      arch = "darktable";
      nixpkgs = "darktable";
      description = "RAW workflow and non-destructive image development.";
    };

    krita = {
      arch = "krita";
      nixpkgs = "krita";
      description = "Raster artwork and digital painting.";
    };

    inkscape = {
      arch = "inkscape";
      nixpkgs = "inkscape";
      description = "SVG illustration and vector asset creation.";
    };

    rawtherapee = {
      arch = "rawtherapee";
      nixpkgs = "rawtherapee";
      description = "Raw editor focused on tonal and color pipeline control.";
    };
  };

  video = {
    kdenlive = {
      arch = "kdenlive";
      nixpkgs = "kdenlive";
      description = "NLE editor for timeline edits and simple effects stacks.";
    };

    blender = {
      arch = "blender";
      nixpkgs = "blender";
      description = "3D creation suite and compositor for motion visuals.";
    };

    shotcut = {
      arch = "shotcut";
      nixpkgs = "shotcut";
      description = "Multiplatform editor for fast cuts and quick exports.";
    };

    ffmpeg = {
      arch = "ffmpeg";
      nixpkgs = "ffmpeg";
      description = "Command-line transcode/mux/probe and asset automation layer.";
    };

    natron = {
      arch = "natron";
      nixpkgs = "natron";
      aur = true;
      description = "Node-based compositor (AUR for distro plane where needed).";
    };
  };
}
