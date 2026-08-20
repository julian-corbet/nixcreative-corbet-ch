# Proves the cluster module resolves what it claims and REFUSES what it claims to refuse, both
# directions, through the real renderer and the real app grammar.
#
# Both halves matter and neither is enough alone. A guard nobody has watched fire is a comment; a
# guard that fires on everything is a wall. So every case below is a complete, otherwise-valid
# surface with exactly one thing wrong, and the `control` case is the same shape with nothing wrong
# and MUST render -- without it, a typo in the shared base would make every other case "pass" for
# the wrong reason.
#
# SOME OF THE REFUSALS ARE NOT GUARDS AT ALL. Naming an application the catalogue does not hold,
# leaving out the version, saying a workload needs the card, and saying where inside the container
# a directory lives all fail as a type error or an unknown option -- not as assertions. That is the
# stronger kind: a boundary nobody has to remember, because it is unwritable rather than refused.
# `tryEval` cannot tell those apart from a guard, so the ones that ARE guards additionally have
# their message asserted by content.
{ pkgs, lib, nixidy, appsModule, clusterModule, values }:

let
  base = import values;

  mkEnv = v: nixidy.lib.mkEnv {
    inherit pkgs;
    modules = [ appsModule clusterModule v ];
  };

  # `tryEval` alone forces only WHNF. Forcing the derivation path is what actually runs the module
  # system's type checks and the assertions underneath.
  renders = v: (builtins.tryEval (builtins.seq (mkEnv v).environmentPackage.drvPath true)).success;

  # An assertion fired, AND it is the one meant: a refusal that happens for an unrelated reason is
  # a false pass, which is exactly the failure this repository's checks exist to make impossible.
  failsWith = infix: v:
    let
      r = builtins.tryEval (lib.any
        (a: !a.assertion && lib.hasInfix infix a.message)
        (mkEnv v).config.nixidy.assertions);
    in
    r.success && r.value;

  warnsWith = infix: v:
    let
      r = builtins.tryEval (lib.any
        (w: w.when && lib.hasInfix infix w.message)
        (mkEnv v).config.nixidy.warnings);
    in
    r.success && r.value;

  # A surface with nothing declared at all, to prove the module is inert until something asks --
  # including that a platform whose namespace and project are REQUIRED does not have to be filled
  # in by a consumer who declares no workload.
  emptyCfg = (mkEnv {
    nixidy.target.repository = "https://example.com/example-org/example-gitops.git";
    nixidy.target.branch = "main";
  }).config;

  goodCfg = (mkEnv base).config;

  with' = f: lib.recursiveUpdate base f;

  results = {
    # ── The control, and the floor ────────────────────────────────────────────────────────────
    "the example surface renders -- without this every refusal below could pass for the wrong reason" =
      renders base;

    "an undeclared surface renders no apps at all, rather than a default one" =
      emptyCfg.nixk3s.apps == { };

    "both declared workloads reach the grammar" =
      lib.sort (a: b: a < b) (lib.attrNames goodCfg.nixk3s.apps)
      == [ "example-graphs" "example-studio" ];

    "the catalogue supplies the port, and the declaration never states one" =
      goodCfg.nixk3s.apps.example-graphs.ports.http.number == 8188
      && goodCfg.nixk3s.apps.example-studio.ports.http.number == 8188;

    "a version becomes the tag, and a whole reference overrides it" =
      goodCfg.nixk3s.apps.example-graphs.image == "yanwk/comfyui-boot:0.0.0"
      && lib.hasInfix "@sha256:" goodCfg.nixk3s.apps.example-studio.image;

    "the catalogue supplies WHERE a directory lives and the declaration supplies WHAT BACKS IT" =
      goodCfg.nixk3s.apps.example-graphs.state.models.mountPath == "/root/ComfyUI/models"
      && goodCfg.nixk3s.apps.example-graphs.state.models.hostPath == "/example/weights"
      && goodCfg.nixk3s.apps.example-studio.state.models.mountPath == "/root/ComfyUI/models"
      && goodCfg.nixk3s.apps.example-studio.state.models.claim == "example-weights";

    "needing the card is a catalogue fact, and it reaches the grammar as one" =
      goodCfg.nixk3s.apps.example-graphs.gpu
      && goodCfg.nixk3s.apps.example-studio.gpu;

    "the module knows which of its workloads hold a device, without deciding anything about one" =
      lib.sort (a: b: a < b) goodCfg.nixcreative.clusterDeviceTenants
      == [ "example-graphs" "example-studio" ];

    "the parent directory sorts before the one nested inside it, so no mount covers another" =
      let keys = lib.attrNames goodCfg.nixk3s.apps.example-graphs.state; in
      lib.take 2 keys == [ "home" "models" ];

    "a Secret is named and never carried" =
      goodCfg.nixk3s.apps.example-graphs.secrets ? example-graphs-env
      && goodCfg.nixk3s.apps.example-graphs.secrets.example-graphs-env.envFrom;

    "a deployment's own numbers reach the container, and the catalogue supplies none of them" =
      goodCfg.nixk3s.apps.example-graphs.resources.limits.memory == "2Gi"
      && goodCfg.nixk3s.apps.example-studio.resources.limits == { };

    # ── Unwritable, not merely refused ────────────────────────────────────────────────────────
    "an application the catalogue does not hold is not a value this option has" =
      !renders (with' { nixcreative.applications.example-graphs.app = "nonesuch"; });

    "a workload with no version is refused, because a floating tag is not a default anyone can pick" =
      !renders {
        nixidy.target.repository = "https://example.com/x.git";
        nixidy.target.branch = "main";
        nixk3s.appPlatform.gpuResourceName = "example.com/example-device";
        nixcreative.clusterPlatform = { namespace = "x"; project = "x"; };
        nixcreative.applications.x = { app = "comfyui"; };
      };

    "a declaration cannot say that a workload needs the card -- that is not one of its options" =
      !renders (with' { nixcreative.applications.example-graphs.gpu = false; });

    "a declaration cannot say where inside the container a directory lives" =
      !renders (with' { nixcreative.applications.example-graphs.state.models.mountPath = "/elsewhere"; });

    # ── The guards, each with its message asserted ────────────────────────────────────────────
    "backing a directory the application does not use is refused" =
      failsWith "must back every directory it uses"
        (with' { nixcreative.applications.example-studio.state.nowhere.hostPath = "/example/nope"; });

    "leaving a directory it DOES use unbacked is refused" =
      failsWith "must back every directory it uses"
        (lib.recursiveUpdate base { nixcreative.applications.example-studio.state = lib.mkForce { }; });

    "a directory backed by both a claim and a node path is refused" =
      failsWith "EITHER an existing claim OR a node path"
        (with' { nixcreative.applications.example-graphs.state.models.claim = "example-claim"; });

    "weights on a node path that is created when missing is refused, because empty is the failure" =
      failsWith "must already exist before the workload starts"
        (with' { nixcreative.applications.example-graphs.state.models.hostPathType = "DirectoryOrCreate"; });

    "an override that stops routing renders into the directory it backs is refused" =
      failsWith "nothing it is told mentions that path"
        (with' { nixcreative.applications.example-graphs.env.CLI_ARGS = "--listen 0.0.0.0"; });

    "two workloads anchoring one namespace is refused" =
      failsWith "Exactly one workload may create a namespace"
        (with' { nixcreative.applications.example-studio.createNamespace = true; });

    "two workloads on one slot is refused" =
      failsWith "is claimed by 2 applications"
        (with' { nixcreative.applications.example-studio.slot = 12; });

    # ── The warnings that are not refusals ────────────────────────────────────────────────────
    # Both of these are real mistakes and neither is an eval error, for the same reason: what makes
    # them mistakes is something one deployment can see and this repository cannot.
    "scale-to-zero with no wake front warns rather than refuses" =
      warnsWith "nothing brings it back"
        (with' { nixcreative.applications.example-graphs.wake = lib.mkForce null; });

    "exposing an application that authenticates nobody warns rather than refuses" =
      let v = with' { nixcreative.applications.example-studio.exposure = "public"; }; in
      warnsWith "authenticates nobody" v && renders v;

    "and neither warning fires on the example surface itself" =
      !(warnsWith "nothing brings it back" base)
      && !(warnsWith "authenticates nobody" base);
  };

  failed = lib.filter (n: !results.${n}) (lib.attrNames results);
in
pkgs.runCommand "nixcreative-cluster-eval" { } (
  if failed == [ ]
  then ''
    echo "nixcreative: all ${toString (lib.length (lib.attrNames results))} cluster-eval properties hold"
    touch $out
  ''
  else ''
    echo "nixcreative cluster-eval FAILED (${toString (lib.length failed)}/${toString (lib.length (lib.attrNames results))}):" >&2
    ${lib.concatMapStringsSep "\n" (n: ''echo "  - ${n}" >&2'') failed}
    exit 1
  ''
)
