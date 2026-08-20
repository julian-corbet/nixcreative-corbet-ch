#
# nixcreative's cluster surface: declare which generative-media applications run in the cluster,
# and render them.
#
# ── THIS MODULE DOES NOT IMPLEMENT KUBERNETES, AND THAT IS THE DESIGN ──────────────────────────
#
# A sibling repository's whole subject is the app grammar: a workload declares WHAT IT NEEDS -- an
# image, ports, an exposure class, whether it may sleep, whether it needs a graphics device, which
# directories it reads and writes and what backs them -- and that grammar renders the Argo CD
# Application, the Namespace, the Deployment and the Service. Everything expressible in those terms
# is expressed in them: this module DEFINES INTO `nixk3s.apps` and renders no Kubernetes object of
# its own.
#
# So it is a translator. What it adds is the one thing the grammar cannot know: what these
# particular applications ARE. Which directory holds weights and is therefore useless empty; which
# argument routes the product of the work somewhere durable; how patient a probe has to be before
# it is calling a fifteen-minute start a failure; whether anybody has to log in.
#
# IMPORT THE GRAMMAR ALONGSIDE IT. `nixk3s.apps` is declared there, not here, and a render that
# composes this module without it fails with "the option `nixk3s.apps' does not exist".
#
# ── THE KNOWLEDGE/VALUE SPLIT, ENFORCED RATHER THAN TRUSTED ────────────────────────────────────
#
# `lib/applications.nix` holds what is true of the software anywhere. A declaration holds what is
# true of one cluster. The two cannot supply each other's half, and the guards below are what makes
# that a rule rather than a habit: the catalogue says WHERE inside the container a directory lives
# and only a declaration can say WHAT BACKS IT, so a workload whose weights live on a node path is
# refused when nothing backs it rather than quietly rendered onto a pod's ephemeral filesystem.
#
# THE DEVICE IS THE SHARPEST CASE OF THE SPLIT. The catalogue says the process puts work on a
# graphics device. It does not say what the cluster calls that device, how many exist, or who
# yields it -- those are four fleet facts, they live wherever the fleet is described, and the
# grammar underneath refuses to render a device request until the site has named its own.
#
# ── THE MODEL HALF ─────────────────────────────────────────────────────────────────────────────
#
# `lib/voices.nix` says WHICH speech model an application serves, where the model is the thing the
# image was built around rather than content loaded into it. This module does three things with
# that and no more: it refuses a catalogue entry that names a model nobody catalogued, it publishes
# what the declared workloads serve so a consumer does not have to re-derive it, and it warns when
# a declared workload serves weights whose licence does not clearly permit commercial use. The last
# one warns rather than refuses for the usual reason -- non-commercial use is perfectly legitimate
# and whether THIS deployment is commercial is not a fact this repository can see -- but it is not
# silent either, because a licence read wrong is the expensive kind of mistake.
{ config, lib, ... }:

let
  cfg = config.nixcreative;
  platform = cfg.clusterPlatform;
  catalogue = (import ../lib/applications.nix { }).applications;
  voices = (import ../lib/voices.nix { }).voices;

  declared = lib.filterAttrs (_: w: w.enable) cfg.applications;
  workloads = lib.mapAttrsToList (name: w: { inherit name w; entry = catalogue.${w.app}; }) declared;

  # A catalogue reason is written as a paragraph and quoted back inside a one-line message.
  oneLine = s: lib.concatStringsSep " " (lib.filter (x: x != "") (lib.splitString "\n" s));

  # A whole reference wins over a repository plus a tag, which is what pinning by digest looks
  # like. The catalogue never carries either: a version is a deployment's choice and a digest is
  # one deployment's proof of what it is running.
  #
  # AND SOMETIMES THE CATALOGUE CARRIES NO REPOSITORY AT ALL, because nobody publishes a runnable
  # container of that application and every operator builds their own. Then there is nothing to put
  # a version on and the declaration's whole reference is the only image there is; the assertion
  # below is what says so in words, and this throw only exists so that a surface which somehow got
  # past it cannot render a pod with an empty image.
  imageOf = entry: w:
    if w.image != null then w.image
    else if entry.image != null then "${entry.image}:${w.version}"
    else throw "nixcreative: no image reference -- the catalogue publishes none and the declaration supplies none";

  portsOf = entry: lib.mapAttrs (_: number: { inherit number; }) entry.ports;

  # The split in one function: WHERE inside the container comes from the catalogue, WHAT BACKS IT
  # comes from the declaration, and neither side can supply the other's half.
  stateOf = entry: w:
    lib.mapAttrs
      (key: backing: {
        # `or null` rather than a raw attribute error: a declaration that backs a directory this
        # application does not use is a real mistake with a real message below, and a Nix
        # "attribute missing" thrown from inside the renderer is not that message.
        mountPath = entry.state.${key} or null;
        inherit (backing) claim hostPath hostPathType readOnly;
      })
      w.state;

  probesOf = entry:
    lib.optionalAttrs (entry.readiness != null) {
      readiness = { port = entry.primaryPort; } // entry.readiness;
    };

  # Whole Secrets, loaded wholesale. Nothing here can carry a secret's CONTENT, which is what makes
  # a declaration written against this module safe to publish.
  secretsOf = w:
    lib.listToAttrs (map (s: lib.nameValuePair s { secret = s; envFrom = true; }) w.envFromSecrets);

  envOf = entry: w: entry.env // w.env;
  argsOf = entry: w: entry.args ++ w.args;

  # Everything the process is TOLD, as one list of strings: the environment it is handed and the
  # command line it is given. What the output guard reads.
  toldOf = entry: w: lib.attrValues (envOf entry w) ++ argsOf entry w;

  # Handed to the band model only when the consumer says it is part of the render: `origin` and
  # `slot` are ITS terms, and defining them into a render that does not declare them is an eval
  # error rather than a graceful no-op.
  addressingOf = w:
    lib.optionalAttrs (platform.origin != null) {
      origin = platform.origin;
      inherit (w) slot;
    };

  mkApp = x:
    let inherit (x) entry w; in
    {
      inherit (w) namespace createNamespace project exposure scaling resources;
      inherit (entry) gpu;
      image = imageOf entry w;
      ports = portsOf entry;
      state = stateOf entry w;
      secrets = secretsOf w;
      env = envOf entry w;
      args = argsOf entry w;
      probes = probesOf entry;
    }
    // lib.optionalAttrs (w.wake != null) { inherit (w) wake; }
    // addressingOf w;

  # ── Assertions ────────────────────────────────────────────────────────────────────────────────

  stateAssertions = lib.concatMap
    (x:
      let inherit (x) name w entry; in
      [
        {
          assertion = lib.attrNames w.state == lib.attrNames entry.state;
          message =
            "nixcreative: application `${name}` must back every directory it uses, and backs "
            + (if w.state == { } then "none" else lib.concatMapStringsSep ", " (k: "`${k}`") (lib.attrNames w.state))
            + ". It uses: "
            + (if entry.state == { } then "nothing"
            else lib.concatStringsSep ", " (lib.mapAttrsToList (k: p: "`${k}` at ${p}") entry.state))
            + ".";
        }
        {
          assertion = lib.all
            (backing: (backing.claim == null) != (backing.hostPath == null))
            (lib.attrValues w.state);
          message =
            "nixcreative: application `${name}` must back each directory with EITHER an existing claim OR a "
            + "node path, never both and never neither. A directory with no backing is a pod's own "
            + "filesystem, which is discarded on every restart -- and a workload that sleeps restarts "
            + "every time somebody wakes it.";
        }
      ])
    workloads;

  # THE GUARD FOR AN EMPTY DIRECTORY THAT IS NOT AN ERROR ANYWHERE ELSE. A node path created on
  # demand is a directory with nothing in it, and nothing in Kubernetes, in the kubelet or in the
  # application treats that as a failure -- so the catalogue names the directories where empty is
  # the whole problem, and this refuses the backing that produces one. It reads the reason out of
  # the catalogue rather than restating it, so there is exactly one copy of why.
  #
  # A CLAIM IS NOT CHECKED, and that is the honest boundary rather than an omission: whether a
  # volume already holds weights is a fact about storage this repository cannot see. `hostPathType`
  # is a fact it can.
  existenceAssertions = lib.concatMap
    (x:
      let inherit (x) name w entry; in
      lib.mapAttrsToList
        (key: reason: {
          assertion =
            let backing = w.state.${key} or null; in
            backing == null
            || backing.hostPath == null
            || !(lib.hasSuffix "OrCreate" backing.hostPathType);
          message =
            "nixcreative: application `${name}` backs `${key}` with a node path that is created when it is "
            + "missing, and `${key}` must already exist before the workload starts: "
            + oneLine reason
            + ". Use a `hostPathType` that refuses to start on a missing path.";
        })
        entry.mustExist)
    workloads;

  # THE GUARD FOR WORK THAT LANDS NOWHERE. The catalogue routes the product of the work into one of
  # the directories it declares, by telling the process a path -- and the environment a declaration
  # supplies is merged OVER the catalogue's, so an override of the wrong variable silently unhooks
  # the two. Nothing fails when that happens: renders are produced, reported, and written onto the
  # container's own filesystem, where they survive exactly until the pod restarts.
  outputAssertions = lib.concatMap
    (x:
      let
        inherit (x) name w entry;
        key = entry.outputState;
        path = entry.state.${key} or null;
      in
      lib.optional (key != null) {
        assertion = path != null && lib.any (t: lib.hasInfix path t) (toldOf entry w);
        message =
          "nixcreative: application `${name}` writes its output into `${key}` at ${toString path}, and "
          + "nothing it is told mentions that path. The catalogue points the process at that directory "
          + "with an argument; a declaration whose `env` or `args` replaces that argument without "
          + "repeating the path leaves every render on the pod's own filesystem, discarded at the next "
          + "restart.";
      })
    workloads;

  # THE GUARD FOR AN APPLICATION NOBODY PUBLISHES AN IMAGE OF. Most of what runs here has a
  # community container somebody maintains, and for those the catalogue names the repository and a
  # declaration names the version. For the rest there is no reference that is true of the software
  # anywhere -- upstream ships a build recipe written against one vendor's compute runtime, and the
  # image a cluster actually runs was built by whoever runs it. `image = null` in the catalogue is
  # that fact, and this is what stops it becoming a silent hole: a version with nothing to hang it
  # on is not an image.
  imageAssertions = lib.concatMap
    (x:
      let inherit (x) name w entry; in
      lib.optional (entry.image == null) {
        assertion = w.image != null;
        message =
          "nixcreative: application `${name}` has no image reference anybody publishes -- upstream ships a "
          + "build recipe rather than a container, so every cluster runs one it built -- and this "
          + "declaration supplies none. Give it a whole `image` reference; a `version` alone has no "
          + "repository to hang on. Pin it by digest if you can: a cold start here is measured in minutes, "
          + "so a moving tag is a debugging session nobody can reproduce.";
      })
    workloads;

  # THE GUARD FOR A MODEL NOBODY CATALOGUED. `serves` is the seam between the two catalogues in
  # `lib/`, and a seam nothing checks is a typo waiting to be read as a fact. This one cannot fire
  # on a declaration -- which model an application serves is knowledge, not a value -- so what it
  # protects is an edit to `lib/applications.nix` that names a model `lib/voices.nix` does not
  # hold, which would otherwise surface as an attribute error from inside the renderer or, worse,
  # as nothing at all.
  servesAssertions = lib.concatMap
    (x:
      let inherit (x) name entry; in
      map
        (m: {
          assertion = voices ? ${m};
          message =
            "nixcreative: application `${name}` serves `${m}`, which is not in the voice catalogue. "
            + "Catalogued models: " + lib.concatStringsSep ", " (lib.attrNames voices) + ".";
        })
        entry.serves)
    workloads;

  # A namespace outlives every workload in it, so exactly one thing may own it. Two anchors is not a
  # merge, it is two Namespace objects Argo will fight over.
  anchorAssertions =
    let
      anchors = lib.filter (x: x.w.createNamespace) workloads;
      byNs = lib.groupBy (x: x.w.namespace) anchors;
    in
    lib.mapAttrsToList
      (ns: xs: {
        assertion = lib.length xs == 1;
        message =
          "nixcreative: namespace `${ns}` is anchored by ${toString (lib.length xs)} applications ("
          + lib.concatMapStringsSep ", " (x: "`${x.name}`") xs
          + "). Exactly one workload may create a namespace.";
      })
      byNs;

  slotAssertions =
    let
      claimed = lib.filter (x: x.w.slot != null) workloads;
      bySlot = lib.groupBy (x: toString x.w.slot) claimed;
    in
    lib.mapAttrsToList
      (slot: xs: {
        assertion = lib.length xs == 1;
        message =
          "nixcreative: slot ${slot} is claimed by ${toString (lib.length xs)} applications ("
          + lib.concatMapStringsSep ", " (x: "`${x.name}`") xs
          + "). A slot is one identity in several address spaces at once; two workloads on one number "
          + "is two workloads on one address.";
      })
      bySlot;

  # A warning is `{ when; message; }` -- the renderer decides whether to print it, so the condition
  # travels with the text rather than being applied here.
  # A workload's licence position, which is a property of the WEIGHTS it serves and not of the
  # software serving them. Warned rather than refused, and the reason is not squeamishness: running
  # a non-commercial model for non-commercial work is exactly what its licence is for, and whether
  # this deployment is commercial is not visible from here. What is visible is which weights are
  # about to be served, so the render says so out loud rather than leaving it to whoever reads the
  # model card next.
  licenceWarnings = lib.concatMap
    (x:
      let inherit (x) name entry; in
      lib.concatMap
        (m:
          let v = voices.${m} or null; in
          lib.optional (v != null && v.licence.commercialUse != "yes") {
            when = true;
            message =
              "nixcreative: application `${name}` serves ${v.name} (${v.hfRepo}), whose licence "
              + "(${v.licence.name}) does not clearly permit commercial use: "
              + oneLine (toString v.licence.caveat)
              + " This warns rather than refuses -- non-commercial use is what such a licence is for, and "
              + "whether this deployment is commercial is not something this repository can see.";
          })
        entry.serves)
    workloads;

  warnings = lib.concatMap
    (x:
      let inherit (x) name w entry; in
      [
        {
          when = w.scaling == "scale-to-zero" && w.wake == null;
          message =
            "nixcreative: application `${name}` is declared scale-to-zero with no wake front, so nothing "
            + "brings it back. At zero replicas that is not an idle workload, it is an unreachable one.";
        }
        {
          when = !entry.authenticates && w.exposure == "public";
          message =
            "nixcreative: application `${name}` authenticates nobody and is declared `public`. Every "
            + "visitor gets the operator's own session, on a workload that executes graphs beside the "
            + "weights and the output directory. This warns rather than refuses because whether an "
            + "authenticating front sits between it and the world is something a deployment can see and "
            + "this repository cannot -- if there is none, close it.";
        }
        {
          when = w.slot != null && platform.origin == null;
          message =
            "nixcreative: application `${name}` claims slot ${toString w.slot}, and "
            + "`nixcreative.clusterPlatform.origin` is unset -- so the number is checked for collisions "
            + "inside this repository and by nothing for which RANGE it may come from.";
        }
      ])
    workloads;

  commonOptions = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to render this workload. Declaring the attribute is declaring the workload, so this
        defaults to true; set false to park a declaration without rendering it.
      '';
    };

    namespace = lib.mkOption {
      type = lib.types.str;
      default = platform.namespace;
      defaultText = lib.literalExpression "config.nixcreative.clusterPlatform.namespace";
      description = "Namespace this workload lands in.";
    };

    createNamespace = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this workload anchors its namespace. Defaults to false, because these applications
        share one namespace by default and exactly one of them may own it.
      '';
    };

    project = lib.mkOption {
      type = lib.types.str;
      default = platform.project;
      defaultText = lib.literalExpression "config.nixcreative.clusterPlatform.project";
      description = "Delivery project this workload's Application belongs to.";
    };

    slot = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = ''
        THE POSITION this workload holds in the fleet's ordered identity space. Not an address --
        the layers underneath map it into however many address spaces the fleet keeps, which is
        why nothing here moves one. The VALUE is a fleet fact and belongs to the consumer.
      '';
    };

    exposure = lib.mkOption {
      type = lib.types.enum [ "internal" "nb" "public" ];
      default = "internal";
      description = ''
        Who can reach it, as a CLASS rather than an address. Defaults to the closed answer, and for
        an application the catalogue marks as authenticating nobody that default is the only one
        that is safe without something else in front of it.
      '';
    };

    scaling = lib.mkOption {
      type = lib.types.enum [ "always" "scale-to-zero" ];
      default = "always";
      description = ''
        Whether the workload may idle to zero replicas.

        The catalogue records whether sleeping is SAFE for a given application -- whether anything
        fires on a timer or watches a directory, which is what makes zero replicas lossy rather
        than merely cold. Whether it is WANTED is a deployment's call, because the wake path is one
        cluster's routing and this repository cannot see whether that path is healthy.

        For a workload that holds a graphics device the case for sleeping is stronger than idle
        capacity: a pod at zero replicas is a card another tenant can have.
      '';
    };

    wake = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "keda" "sablier" ]);
      default = null;
      description = ''
        Which front wakes it from zero. Meaningless unless `scaling = "scale-to-zero"`, and its
        absence there is warned about: nothing brings the workload back.

        FOR AN APPLICATION THAT HOLDS THE DEVICE the choice is not free, and the grammar underneath
        is where that is enforced: the first request has to be held until the pod actually holds the
        card and be answered by the application itself, because a front that admits it earlier turns
        "the device is busy" into an error at the edge.
      '';
    };

    state = lib.mkOption {
      default = { };
      description = ''
        What backs each directory the catalogue says this application uses, keyed by the SAME names.
        Backing a directory it does not use, or leaving one it does use unbacked, is an eval error
        rather than a surprise at runtime.
      '';
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          claim = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "An existing PersistentVolumeClaim, by name. Nothing here creates one.";
          };
          hostPath = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "A directory on the node. Pins the workload to whichever node holds it.";
          };
          hostPathType = lib.mkOption {
            type = lib.types.str;
            default = "Directory";
            description = ''
              The hostPath type, when a node path is what backs it. Defaults to the form that
              REFUSES to start on a missing path, because for most of what these applications read
              -- weights above all -- an auto-created empty directory is a workload that comes up
              healthy and can do nothing. A directory the application populates itself is the
              exception and says so by asking for one of the `OrCreate` forms; on a directory the
              catalogue marks as needing to exist, asking for one is refused.
            '';
          };
          readOnly = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether the mount is read-only. A real choice for a shared model store: read-only
              costs the in-app installers that write into it and buys a workload that cannot alter
              weights other tenants read.
            '';
          };
        };
      });
    };

    resources = lib.mkOption {
      default = { };
      description = ''
        What the scheduler must find for this workload and what it may not exceed. Purely a
        deployment's half -- a number here is measured on one box, against one card, with one
        model library, and nothing about it is true of the software anywhere else, which is why the
        catalogue carries none.

        A MEMORY LIMIT IS A KILL THRESHOLD and a CPU LIMIT IS A THROTTLE, and for this class of
        workload those pull opposite ways: a ceiling on memory stops a runaway model load from
        taking the node down, while a ceiling on CPU makes a bursty load slow rather than the box
        quiet.
      '';
      type = lib.types.submodule {
        options = {
          requests = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            example = { memory = "4Gi"; };
            description = "Compute the scheduler must find before it will place the pod.";
          };
          limits = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            example = { memory = "24Gi"; };
            description = "Ceilings for the workload's own container. The device is never named here.";
          };
        };
      };
    };

    env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Environment this deployment adds, merged over whatever the catalogue sets. Values only --
        anything secret belongs in a Secret and arrives through `envFromSecrets`.

        THIS IS WHERE A CARD'S OWN QUIRKS ARRIVE. A runtime told to report a different hardware
        target is a fact about one piece of silicon, so the catalogue cannot hold it and this can.
        Overriding a variable the catalogue already sets REPLACES it, which is why the output guard
        exists: an override that drops the argument routing renders into their directory is refused
        rather than discovered later.
      '';
    };

    envFromSecrets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Secrets loaded wholesale, by name. Named rather than carried: nothing in this repository
        can hold a secret's contents, which is what makes a declaration written here publishable.
      '';
    };

    args = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Arguments appended to whatever the catalogue sets.";
    };

    image = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        A whole image reference, overriding the catalogue's repository and this workload's version.
        This is where a digest pin goes, and pinning by digest is what makes two syncs of an
        identical rendered tree run identical code -- which matters more here than almost anywhere:
        a cold start of this class of workload is measured in minutes, so a moving tag is a
        debugging session nobody can reproduce.
      '';
    };
  };
in
{
  options.nixcreative.clusterPlatform = {
    namespace = lib.mkOption {
      type = lib.types.str;
      description = ''
        Namespace these applications share unless a declaration says otherwise. REQUIRED, and
        defaulted nowhere: a namespace is one cluster's fact, and a public repository that shipped
        a plausible-looking default would be shipping somebody's real one.
      '';
    };

    project = lib.mkOption {
      type = lib.types.str;
      description = ''
        Delivery project their Applications belong to unless a declaration says otherwise.
        Required for the same reason as `namespace`.
      '';
    };

    origin = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        THE IDENTITY THIS REPOSITORY'S APPLICATIONS ARE ADDRESSED UNDER, when the render composes
        the band model. A repository naming itself is not a fleet fact; which band that name binds
        is, and it lives in whatever repository owns the fleet. Left null, slots are still checked
        for collisions here and by nothing for range.
      '';
    };
  };

  options.nixcreative.applications = lib.mkOption {
    default = { };
    description = ''
      The generative-media applications that run in the cluster, keyed by a name of your choosing.

      THE ENUM IS THE PLACEMENT RULE. It is built from `lib/applications.nix`, so an application
      this repository does not catalogue is not a refused value here -- it is not a value. What
      belongs in that catalogue is what this repository's gates already decide: a tool whose output
      records judgements only its operator made, with a display mode of its own, whose working set
      is model weights. A model server that answers an API and authors nothing fails the second
      gate no matter what it is made of, and has an owner elsewhere.
    '';
    example = lib.literalExpression ''
      {
        example-graphs = {
          app = "comfyui";
          version = "0.0.0";
          exposure = "nb";
          slot = 42;
          scaling = "scale-to-zero";
          wake = "sablier";
          state.models.hostPath = "/example/weights";
          state.home = { hostPath = "/example/state/graphs"; hostPathType = "DirectoryOrCreate"; };
          state.output.hostPath = "/example/renders";
          env.HSA_OVERRIDE_GFX_VERSION = "0.0.0";
        };
      }
    '';
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = commonOptions // {
        app = lib.mkOption {
          type = lib.types.enum (lib.attrNames catalogue);
          description = "Which application, from the catalogue. Available: ${lib.concatStringsSep ", " (lib.attrNames catalogue)}.";
        };

        version = lib.mkOption {
          type = lib.types.str;
          description = "Which version this workload runs, used as the image tag. Required, and defaulted nowhere.";
        };
      };
    }));
  };

  # ── Computed, read-only ───────────────────────────────────────────────────────────────────────
  options.nixcreative.clusterSlots = lib.mkOption {
    type = lib.types.attrsOf lib.types.ints.unsigned;
    readOnly = true;
    default = lib.listToAttrs
      (map (x: lib.nameValuePair x.name x.w.slot) (lib.filter (x: x.w.slot != null) workloads));
    defaultText = lib.literalExpression "every declared workload that claims a slot";
    description = ''
      workload -> the position it claims. Nothing is rendered from it here: what an address looks
      like is the private layer's business, and this is what that layer reads to build one.
    '';
  };

  # ── Computed, read-only ───────────────────────────────────────────────────────────────────────
  options.nixcreative.clusterDeviceTenants = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    readOnly = true;
    default = map (x: x.name) (lib.filter (x: x.entry.gpu) workloads);
    defaultText = lib.literalExpression "every declared workload whose catalogue entry needs a graphics device";
    description = ''
      Which of the declared workloads put work on a graphics device, by declaration name. Nothing is
      rendered from it: whether the device they name is one card or eight, and what happens when two
      of them want it at once, is decided by whoever owns the hardware. This is the list that layer
      reads so it does not have to re-derive it from the catalogue and get a different answer.
    '';
  };

  # ── Computed, read-only ───────────────────────────────────────────────────────────────────────
  options.nixcreative.clusterVoices = lib.mkOption {
    type = lib.types.attrsOf (lib.types.listOf lib.types.str);
    readOnly = true;
    default = lib.listToAttrs
      (map (x: lib.nameValuePair x.name x.entry.serves)
        (lib.filter (x: x.entry.serves != [ ]) workloads));
    defaultText = lib.literalExpression "every declared workload that serves a named model";
    description = ''
      workload -> the models it serves, by key into `lib/voices.nix`. Nothing is rendered from it:
      which model an application serves is baked into the image it runs, so there is no manifest
      field for it. This exists so that a consumer can answer "what voices does this cluster
      actually serve, and under what licences" from the configuration rather than by opening a
      container.

      A workload whose model set is CONTENT -- a graph editor running whatever checkpoints a
      deployment installed -- appears nowhere in here, which is the honest answer rather than an
      empty one.
    '';
  };

  # ── Computed, read-only ───────────────────────────────────────────────────────────────────────
  options.nixcreative.voiceLicenceReview = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    readOnly = true;
    default = lib.mapAttrs (_: v: v.licence.caveat)
      (lib.filterAttrs (_: v: v.licence.commercialUse != "yes") voices);
    defaultText = lib.literalExpression "every catalogued voice model whose licence is not plainly commercial-friendly";
    description = ''
      model -> what its licence restricts, for every model in the catalogue whose licence does not
      clearly permit commercial use. Derived from the catalogue and NOT from what is declared, on
      purpose: the question it answers is asked before a workload exists, by whoever is choosing
      which model to serve.

      It is a list of restrictions rather than a list of refusals. Two of the entries carry
      permissive CODE and non-commercial WEIGHTS, which is the shape that gets read wrong -- and
      one of those carries no licence tag at all, so anything that keys on the tag records it as
      unlicensed and moves on.
    '';
  };

  config = {
    nixk3s.apps = lib.listToAttrs (map (x: lib.nameValuePair x.name (mkApp x)) workloads);
    nixidy.assertions =
      stateAssertions ++ existenceAssertions ++ outputAssertions ++ imageAssertions
      ++ servesAssertions ++ anchorAssertions ++ slotAssertions;
    nixidy.warnings = warnings ++ licenceWarnings;
  };
}
