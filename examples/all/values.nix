# Placeholder values for the cluster module — the file that makes the render check real.
# `nix flake check` renders the whole surface from here, so a module that stops evaluating, or that
# grows a required value nobody supplies, fails in CI rather than in somebody's cluster.
#
# NOTHING HERE IS REAL. Every namespace, path, name, number, image and device resource is invented
# for this file, and no credential appears in any form — only the NAME of a Secret that would hold
# one.
#
# FOUR DECLARATIONS, chosen to cover the paths that differ in what gets RENDERED rather than
# merely in what evaluates. The first two are two deployments of ONE application, which is not a
# shape anybody would run — an example file is not a cluster, and what they exist to do is exercise
# both halves of every branch:
#
#   - one that anchors a namespace, takes its image as a repository plus a version, sleeps behind a
#     wake front, backs every directory on a node path, and adds the environment a particular piece
#     of silicon needs;
#   - one that joins that namespace rather than creating a second one, is pinned by digest, stays
#     resident, reads its weights read-only out of an existing claim instead of off a node — which
#     is the other backing, and the one the existence guard deliberately cannot check.
#
# The other two are the voice tier, in a SECOND namespace of its own, and they are here because
# between them they are the only place several branches are taken at all:
#
#   - a workload that does NOT burn the card, so a rendered pod with no device request is something
#     the checks can actually read rather than a claim about an option;
#   - a workload whose catalogue entry publishes no image, so the whole reference is not an
#     override of anything — it is the only image there is, and leaving it out is refused.
{
  # Required by the nixidy environment itself, not by any module here.
  nixidy.target.repository = "https://example.com/example-org/example-gitops.git";
  nixidy.target.branch = "main";

  # THE GRAMMAR REFUSES TO GUESS THIS, and that refusal is the point: an application says it puts
  # work on a graphics device, and what a cluster CALLS that device is the cluster's own fact. A
  # wrong value here is silent — the pod schedules happily, with no device and no error.
  nixk3s.appPlatform.gpuResourceName = "example.com/example-device";

  nixcreative.clusterPlatform = {
    namespace = "example-generative";
    project = "example-heavy";
  };

  # Anchors the namespace, and takes the catalogue's repository with a version rather than a whole
  # reference. Every directory is a node path: the weights and the renders on a form that refuses to
  # start when the path is missing, the working tree on one that creates it, which is the split the
  # catalogue's `mustExist` describes. Sleeps, and names the front that wakes it — without which the
  # module warns that nothing brings it back.
  nixcreative.applications.example-graphs = {
    app = "comfyui";
    version = "0.0.0";
    createNamespace = true;
    exposure = "nb";
    slot = 12;

    scaling = "scale-to-zero";
    wake = "sablier";

    state.models.hostPath = "/example/weights";
    state.home = {
      hostPath = "/example/state/graphs";
      hostPathType = "DirectoryOrCreate";
    };
    state.output.hostPath = "/example/renders";

    # A runtime told to report a different hardware target: a fact about one card, which is exactly
    # why the catalogue cannot hold it. The value is invented — a real one is read off real silicon.
    env.HSA_OVERRIDE_GFX_VERSION = "0.0.0";

    # Measured on one box against one card, so the catalogue carries none of it. A ceiling on
    # memory and none on CPU, deliberately: the first stops a runaway load taking the node down,
    # the second would only make a bursty one slow.
    resources.requests.memory = "1Gi";
    resources.limits.memory = "2Gi";

    envFromSecrets = [ "example-graphs-env" ];
  };

  # Joins the namespace above rather than anchoring a second one, and carries a whole reference so
  # two syncs of an identical tree run identical code. Its weights come out of an existing claim,
  # mounted read-only: a shared model store this deployment reads and may not alter.
  nixcreative.applications.example-studio = {
    app = "comfyui";
    version = "0.0.0";
    image = "registry.example.com/example-org/example-graphs:0.0.0@sha256:0000000000000000000000000000000000000000000000000000000000000000";
    exposure = "internal";
    slot = 13;

    state.models = {
      claim = "example-weights";
      readOnly = true;
    };
    state.home = {
      hostPath = "/example/state/studio";
      hostPathType = "DirectoryOrCreate";
    };
    state.output.hostPath = "/example/renders-studio";
  };

  # ── The voice tier, in a namespace of its own ───────────────────────────────────────────────
  #
  # Anchoring a SECOND namespace, which is the case the anchor guard exists for: exactly one
  # workload may own each, and two namespaces each anchored once is the shape that proves the guard
  # counts per namespace rather than per render.

  # The half that never touches the card. Nothing here says so — `gpu` is not a declaration's
  # option — so what a reader sees is the absence of every device-shaped thing in the manifest,
  # which is exactly what the render check reads back.
  nixcreative.applications.example-narration = {
    app = "kokoro";
    version = "0.0.0";
    namespace = "example-voice";
    createNamespace = true;
    exposure = "internal";
    slot = 14;

    # Extra voice packs, on a node path that is CREATED when missing — allowed here and refused for
    # the graph editor's weights above, because the catalogue says which directories are useless
    # empty and this is not one of them: every released voice ships inside the image.
    state.voices = {
      hostPath = "/example/state/voices";
      hostPathType = "DirectoryOrCreate";
    };

    # Cores rather than a card, which is the whole point of this half of the tier.
    resources.requests.cpu = "500m";
    resources.requests.memory = "1Gi";
    resources.limits.memory = "2Gi";
  };

  # The half that burns the card. Its catalogue entry publishes no image — nobody ships a runnable
  # container of it — so the whole reference below is not overriding anything, and a declaration
  # without one is refused rather than rendered with a version hanging off nothing.
  nixcreative.applications.example-cloning = {
    app = "chatterbox";
    version = "0.0.0";
    image = "registry.example.com/example-org/example-cloning:0.0.0@sha256:1111111111111111111111111111111111111111111111111111111111111111";
    namespace = "example-voice";
    exposure = "nb";
    slot = 15;

    # A card is worth freeing when nobody is using it, which is a stronger case for sleeping than
    # idle memory ever is.
    scaling = "scale-to-zero";
    wake = "sablier";

    # All three directories are filled by the running process, so all three may be created when
    # missing: a cold start is slow and correct, which is not what `mustExist` is about.
    state.cache = {
      hostPath = "/example/state/cloning-cache";
      hostPathType = "DirectoryOrCreate";
    };
    state.reference = {
      hostPath = "/example/state/cloning-reference";
      hostPathType = "DirectoryOrCreate";
    };
    state.voices = {
      hostPath = "/example/state/cloning-voices";
      hostPathType = "DirectoryOrCreate";
    };

    # A fact about one piece of silicon, invented here like everything else in this file.
    env.HSA_OVERRIDE_GFX_VERSION = "0.0.0";
  };
}
