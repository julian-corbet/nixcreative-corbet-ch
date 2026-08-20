#
# The cluster catalogue: what nixcreative's cluster-side applications ARE.
#
# WHY THIS FILE EXISTS AT ALL, and it is the repository's own gate 2 finally landing somewhere.
# The placement rule says a tool whose working set includes model weights is not a package here:
# a package manager can finish installing a raster editor and it cannot finish installing a model.
# That sends the tool to the cluster. It never sent it to another SUBJECT -- generative media is
# this repository's subject on both planes -- so the cluster half belongs here, in a vocabulary
# that describes a workload instead of a workstation.
#
# WHAT BELONGS HERE. The same three gates, with gate 2 answered the other way round: the thing
# still authors a file whose contents only its operator decided (gate 1), it still has a display
# mode (gate 0), and it needs weights (gate 2) -- so it runs as a workload rather than as a
# package. A model SERVER that answers an API and authors nothing is not this repository's on
# gate 1, whatever it is made of; a media library, a transcoder or a capture pipeline is not this
# repository's on gate 1 either, and each of those has an owner already.
#
# WHAT IS KNOWLEDGE AND WHAT IS A VALUE. Everything in this file is true of the software wherever
# anyone runs it: the port it listens on, the directories it reads and writes, whether it burns a
# GPU, whether it authenticates anybody, how patient a probe has to be before it is calling a slow
# start a failure. Nothing here names an address, a node, a hostname, a namespace, a device-plugin
# resource or a card. Those are one deployment's facts and they arrive from the consumer.
#
# THE GPU IS DECLARED AS A NEED AND NEVER AS AN ALLOCATION. `gpu = true` says the process puts
# work on a graphics device. What the cluster CALLS that device, how many there are, who yields it
# and in what order are four different fleet facts, and not one of them is expressible here.
{}:
{
  applications = {
    comfyui = {
      # A COMMUNITY PACKAGING, and that is a fact worth carrying rather than an accident. ComfyUI
      # upstream publishes source, not an image; every runnable container is somebody's assembly of
      # it, and this one is the assembly that carries a working ROCm stack. A deployment that
      # prefers a different assembly overrides the whole reference -- which is also where a digest
      # pin goes, and pinning by digest is what makes two syncs of an identical tree run identical
      # code. The catalogue carries no tag and no digest: a version is a deployment's choice.
      image = "yanwk/comfyui-boot";

      ports.http = 8188;
      primaryPort = "http";

      # IT BURNS THE CARD, which is the single fact everything else about this workload follows
      # from. Recorded as a NEED and nothing more: the device's name, its count, who yields it and
      # in what order are fleet facts, and a repository that guessed any of them would schedule a
      # pod with no device and no error.
      gpu = true;

      # WHERE, only. What backs each of these can only come from a declaration.
      state = {
        # Checkpoints, LoRAs, VAEs, embeddings, upscalers -- gigabytes of weights, read on every
        # graph execution and WRITTEN by the in-app node manager when it installs a model or a
        # node's assets. Read-only is a legitimate deployment choice and costs those installs.
        models = "/root/ComfyUI/models";

        # The container's whole writable home: the application tree, `custom_nodes`, per-node
        # configuration, saved workflows, the input directory, and the `user-scripts` hook path
        # below. It is one curated directory rather than four, because a custom node installs
        # itself as a git clone and expects the tree around it.
        #
        # IT IS CALLED `home` SO THAT IT SORTS FIRST, and that is a constraint rather than a
        # preference. The model directory lives INSIDE this one, mounts are emitted in
        # attribute-name order, and a shallower mount emitted last covers the deeper one it
        # contains -- so the parent has to sort before the child, and the only lever a catalogue
        # has over that is the name it gives the key.
        home = "/root";

        # Where finished renders land. Separate from `home` on purpose: the product of the work
        # outlives the working tree, and the argument below is what points the process at it.
        output = "/images-out";
      };

      # WHICH OF THOSE MUST ALREADY HOLD SOMETHING, keyed to the same names, with the reason the
      # guard quotes back. A node path that is created on demand is silently empty, and an empty
      # directory is not an error anywhere in this stack -- it is a workload that starts, reports
      # ready, and then cannot do the one thing it exists for.
      mustExist = {
        models = ''
          an auto-created model directory is a ComfyUI that starts happily, serves its graph
          editor, and can execute nothing: every checkpoint node fails at the moment somebody
          queues a prompt, which is minutes after the point at which anything was watching
        '';
        output = ''
          renders are the product, and an auto-created output directory is where they go when the
          real one failed to arrive -- a run that looks successful and leaves its results on a
          path nobody curates or backs up
        '';
      };

      # WHICH DIRECTORY THE PROCESS IS TOLD TO WRITE ITS PRODUCT INTO. The name of a `state` key,
      # so the guard can compare the path against what the process is actually told below; see
      # `modules/cluster.nix` for what it refuses.
      outputState = "output";

      # NOBODY. ComfyUI ships no login, no user model and no authorization of any kind -- every
      # visitor gets the same full graph editor. That is not a gap to be configured around: the
      # graph editor executes custom nodes, custom nodes are arbitrary Python, and the process runs
      # beside the weights and the output directory. Whoever can open it can run code on the node.
      authenticates = false;

      env = {
        # The image's entrypoint reads its whole command line out of this one variable. Two things
        # are being said: bind every interface (a fact about a container, not about a network), and
        # write renders into the `output` mount rather than into the working tree. A declaration
        # that overrides this variable and drops the second half is refused -- see the guard.
        CLI_ARGS = "--listen 0.0.0.0 --output-directory /images-out";
      };

      args = [ ];

      # FIFTEEN MINUTES OF TOLERATED START, and the number is the budget rather than the
      # expectation. A cold start loads a Python stack, initialises the GPU runtime, imports every
      # installed custom node, and -- where a deployment plants the hook described below -- installs
      # those nodes' Python requirements before the server answers anything. On top of that a
      # workload that shares one card can be waiting for another tenant to release it. Readiness is
      # what holds a waiting page up for exactly that long.
      #
      # THERE IS DELIBERATELY NO LIVENESS PROBE, and its absence is the decision. On a process this
      # slow to come up, a guessed liveness probe is how a working application ends up in a restart
      # loop that reads as the application's fault.
      readiness = {
        path = "/";
        periodSeconds = 5;
        failureThreshold = 180;
      };

      note = ''
        A node-graph front end for diffusion models: you wire samplers, conditioners, loaders and
        post-processing into a graph and execute it, one iteration at a time, looking at what came
        out and changing the graph. The operator sits in that loop continuously, which is why this
        is generative media rather than a job somebody queued -- and it needs weights, which is why
        it is a workload rather than a package.

        IT HOLDS THE WHOLE DEVICE WHILE IT RUNS. A second replica does not halve the queue; it is a
        second claim on one card, and on a cluster that hands the device out by count the second
        pod simply never schedules. Two live copies is never the shape of this workload, and its
        durable directories already say so: a rollout that overlaps the old pod and the new one is
        the new one waiting forever for a device the old one will not release until it is ready.

        AMD CARDS OFTEN NEED A GFX OVERRIDE, and it is not in this catalogue. ROCm ships compiled
        kernels for a short list of GFX targets and refuses a card that is architecturally
        compatible but absent from it; telling the runtime to report a supported target is what
        makes those cards work at all. WHICH target is a fact about a specific piece of silicon,
        so it arrives as environment from the declaration, and a wrong value fails at import time
        rather than quietly.

        THE HOOK POINT IS PART OF THE IMAGE, and worth knowing because the alternative is
        mysterious. This packaging sources `/root/user-scripts/pre-start.sh` on every start when it
        is present, which is the generic answer to a problem custom nodes create: a node cloned
        straight into `custom_nodes/` gets no dependency install, because installing dependencies
        is the in-app node manager's job and a git clone never asked it. That path is INSIDE the
        `home` directory above, so a deployment that wants the hook writes it there -- nothing in
        this repository plants one, because a hook is content and content is not vocabulary.

        A ROCM TRAP THAT COSTS AN AFTERNOON: several widely-used custom nodes list `onnxruntime-gpu`
        unconditionally in their requirements, with a marker that checks the machine architecture
        and never the vendor. That package is CUDA-only. Installed on an AMD box it replaces a
        working `onnxruntime` and breaks every node that reaches face-analysis or ONNX inference,
        with an import error that names neither the culprit nor the node that pulled it in.

        IT IS SAFE TO SLEEP, and that is a property of the software rather than of its size.
        Nothing in it fires on a timer, nothing watches a directory, and a graph runs only when
        somebody submits one -- so at zero replicas there is no work that fails to happen, which is
        the actual test. WHETHER it sleeps is a deployment's call, and so is what wakes it; the one
        thing this repository will say about the wake path is that a request arriving while the pod
        is down has to be held until the pod holds the card, because a front that admits it earlier
        turns "the device is busy" into an error at the edge.

        AND IT AUTHENTICATES NOBODY. See `authenticates` above: this is the field that decides how
        far it may be exposed, and the module warns rather than refuses only because whether an
        authenticating front sits between it and the world is something a deployment can see and
        this repository cannot.
      '';
    };
  };
}
