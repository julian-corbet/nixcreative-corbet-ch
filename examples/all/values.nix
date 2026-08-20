# Placeholder values for the cluster module — the file that makes the render check real.
# `nix flake check` renders the whole surface from here, so a module that stops evaluating, or that
# grows a required value nobody supplies, fails in CI rather than in somebody's cluster.
#
# NOTHING HERE IS REAL. Every namespace, path, name, number, image and device resource is invented
# for this file, and no credential appears in any form — only the NAME of a Secret that would hold
# one.
#
# THE CATALOGUE HOLDS ONE APPLICATION, so the two declarations below are two deployments of it
# rather than two different things, and they are chosen to cover the paths that differ in what gets
# RENDERED rather than merely in what evaluates:
#
#   - one that anchors the shared namespace, takes its image as a repository plus a version, sleeps
#     behind a wake front, backs every directory on a node path, and adds the environment a
#     particular piece of silicon needs;
#   - one that joins that namespace rather than creating a second one, is pinned by digest, stays
#     resident, reads its weights read-only out of an existing claim instead of off a node — which
#     is the other backing, and the one the existence guard deliberately cannot check.
#
# Two deployments of one application sharing one card is not a shape anybody would run; an example
# file is not a cluster, and what these two exist to do is exercise both halves of every branch.
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
}
