# What adopting a running workload taught the surface

Every option in `modules/cluster.nix` was written against a workload that did not exist yet. The
test that found the gaps was the opposite one: take a cluster where these applications are **already
running**, write the declaration that describes them in this repository's vocabulary, render it, and
diff the result against the manifest that cluster is already serving — byte for byte.

The bar is byte-identical and it is not pedantry. A rendered manifest that differs from the live one
is a diff the delivery layer will act on, which for a workload holding a single non-overcommittable
device and taking minutes to start is not a pod restart: the old pod has to stop before the new one
can have the card, and the new one re-runs its whole cold start. "Semantically the same" is a
sentence nobody can act on at three in the morning.

Three things came out of it that changed code, and one list that deliberately did not.

## A volume's name is a manifest identifier, not a fact about the software

The catalogue names directories for what they *are* — the working home, the weights, the output —
and one of those names is load-bearing beyond vocabulary: mounts are emitted in attribute-name
order, the weights directory lives *inside* the working home, and a shallower mount emitted last
covers the deeper one it contains. So the parent has to sort first, and the only lever a catalogue
has over that is the name it gives the key.

A cluster that has been running the same application for a year has whatever names it was born
with, and they were not chosen with that constraint in mind. Renaming a volume on a live workload
rewrites the pod template for the sake of a word.

`state.<name>.volumeName` is the answer, and its narrowness is the whole design: it renames the
volume **in the manifest and nowhere else**. Where the directory lands inside the container is still
the catalogue's and is not overridable, so this cannot grow into a second vocabulary for the same
directories. What it *can* do is break the sort constraint above, so a rename that puts a directory
before the one it lives inside warns — the grammar underneath warns about the symptom and advises
renaming keys a consumer does not own, so this one names the cause on the line that could have been
written differently.

## A hook point is the image's; what the hook says is not

Some images source a script off a fixed path before they start. The catalogue had that in prose and
nowhere else, with a closing line to the effect that nothing here plants one because a hook is
content. That sentence is still true and it was hiding a second one: the *point* is not content.

Three facts about the packaging turned out to be knowledge — the path it reads, which of its own
directories that path lives inside, and why the obvious implementation does not work. Mounting the
script there directly crash-loops the pod: a projected volume is read-only with no override, the
entrypoint runs `chmod +x` on the hook before sourcing it, and that failure aborts start-up under
the entrypoint's own `set -e`. So the file has to be **copied** onto the writable directory, which
means a container that runs before the application does.

Which object holds the script and which small image performs the copy are the deployment's, and are
the only two values it supplies. Everything else is derived: the catalogue's one word for the hook
names the volume, the installer container and the scratch directory it reads from, and the copy
command is built from the path and the directory it lives in. Nobody spells a container name, a
mount path or a shell command.

That derivation is the test that separates a term from an escape hatch. If a declaration could have
written the container itself, the option would have been a passthrough wearing a noun.

## A required option whose honest answer is sometimes "none"

`version` was required and defaulted nowhere, for a good reason: a floating tag on a workload whose
cold start is measured in minutes is two syncs of one tree running different code.

Adoption found the hole in it. A workload pinned by digest has nothing for a tag to hang on, and one
whose catalogue entry publishes no repository at all could never use a tag under any circumstances —
yet both had to write something. What gets written is `version = "unused"`, which is a lie in a file
whose entire premise is that it does not contain any.

The mistake was never "no version". It is "no version *and* no whole reference", and that is a
guard, not a required option.

## What still cannot be said here, and why that is right

Reaching byte-identity took a private overlay on the rendered objects, and everything in it stayed
there. None of it is a fact about creative software:

| Field | Why it is not this repository's |
|---|---|
| an added Linux capability | the grammar underneath has no `capabilities.add` and will not grow one — every term it has restricts, and a granted capability is a hole somebody types on purpose |
| a **container**-level seccomp profile | the grammar's own term renders on the *pod*. A live object carrying it on the container cannot be reproduced by that term, and rendering it in the other place is a different manifest — which is the thing the exercise exists to avoid |
| image pull credentials | no term in the grammar at all; a private registry and who may read it is a fleet fact |
| a per-application node selector | which node holds which hardware is the cluster's map |
| a scheduling priority class | who yields the shared device, and in what order, is a tenancy decision between tenants |
| a projected volume's file mode | no term in the grammar |
| a pinned in-cluster address | an address, allocated where addresses are allocated |
| the selector and labels a live object was born with | an adoption seam: a selector is immutable, so re-labelling is a rejected apply rather than a rollout, and the labels a wake front selects on are the mechanism by which the workload is allowed to wake at all |

Two of those are worth reading twice. The seccomp row is the one that would have been easy to get
wrong: the grammar *does* have a seccomp term, so adding one here would have looked like closing a
gap, and it would have rendered the field in a place the live object does not carry it. And the last
row is not a gap in any vocabulary — it is the price of adopting an object rather than creating one,
and it is paid once.
