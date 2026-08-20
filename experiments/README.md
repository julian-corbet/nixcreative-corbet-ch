# experiments

Reproducible verification of the things this repository asserts about somebody else's namespace.

Everything in `lib/` is a claim about an artifact this repository does not control: a package name
in a distribution's database, an attribute path in nixpkgs, a model's parameter count and licence
on a hub. None of those claims can be checked by evaluating this flake, because nothing here
resolves them — the modules publish names and lists, and a host or a cluster resolves them later.
So `nix flake check` proves that the catalogues are *well formed and internally consistent*, and
these scripts prove they are *still true*.

The split is deliberate and worth keeping: a check that needed the network would fail on a
disconnected machine and be disabled within a week, and a verification that ran only inside `nix
flake check` would never be run against the world at all.

| Script | Verifies | Needs |
|---|---|---|
| `verify-packages.sh` | every `arch` name against a real pacman database, every `nixpkgs` attribute by a **forcing** evaluation against this flake's locked nixpkgs | `nix`, `jq`; the pacman half needs an Arch-family host |
| `verify-voices.sh` | every catalogued voice model against the hub: canonical id, licence tag, agreement gate, and what an anonymous fetch actually gets — plus whether its upstream code is still moving | `nix`, `jq`, `curl`, network |

Both read the catalogue **through Nix** (`nix eval --json .#lib.catalogue`, `.#lib.voices`) rather
than parsing the files, so a script cannot drift from what the flake exports.

Both exit non-zero on a disagreement and print what they saw. A disagreement is a finding, not
necessarily a defect here: upstream renames things. What it is never allowed to be is invisible.

**A skip is not a pass.** `verify-packages.sh` on a host with no pacman says so and skips that half;
it does not report the names as verified. Same for an AUR name, which `pacman -Si` cannot see at
all — a failure there would be a false negative, so it is reported as skipped rather than counted.

`open-questions.md` is the other half of this directory: the things that could not be established,
each with what would have to be fetched to settle it. Nothing in it is in a catalogue, and that is
the point — an open question is cheaper to carry than a wrong entry.

Findings that changed how a catalogue is shaped are written up in [`../studies/`](../studies/).
