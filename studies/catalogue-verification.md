# What verifying the catalogues taught the code

Both catalogues in `lib/` are claims about somebody else's namespace, and both are resolved
somewhere other than here — a package name by a host's reconciler, a model id by whatever pulls the
weights. Writing the two verification scripts in [`experiments/`](../experiments/) turned up three
things that changed code rather than documentation.

## Existence is the wrong question to ask nixpkgs

When an attribute is renamed in nixpkgs, the old name does not disappear. It becomes a **throwing
alias**: an attribute that exists and raises the moment anything reads a value off it.

That inverts the obvious check. `pkgs ? qtractor` is `true` for a healthy attribute *and* for a
renamed one, so an existence test passes on exactly the entries that are broken — the worst
direction for a check to be wrong in, because it is silent and confident.

Two places in this repository act on it:

- [`modules/nixos.nix`](../modules/nixos.nix) resolves a selection with `tryEval` over a forced
  value rather than with `?`, and skips a stale mapping with a warning instead of taking the whole
  host evaluation down with it.
- [`experiments/verify-packages.sh`](../experiments/verify-packages.sh) forces `.name`. Anything
  weaker would report the catalogue clean while an entry was dead.

The same trap has a milder cousin one layer up: `builtins.tryEval` alone forces only to weak head
normal form, so `tryEval` over a module evaluation proves almost nothing. The cluster checks force
a derivation path for the same reason.

## A flake input is not a flake output

The first draft of `verify-packages.sh` resolved attributes through a flake reference:

```
nix eval --raw "$root#inputs.nixpkgs.legacyPackages.x86_64-linux.inkscape.name"
```

Every entry failed, with a message about a missing attribute. The message is accurate and
misleading: `#` selects an **output**, so that form looks for a package literally named
`inputs.nixpkgs.…` and finds none — the input is never consulted. Four "failures" in a row that
were entirely the harness.

It now goes through `builtins.getFlake` and reads the input directly. The lesson generalises past
this script: **a verification that fails on everything is a bug in the verification.** A single
failing entry is a finding; a clean sweep of failures is the tool.

## A skip must never look like a pass

The pacman half of `verify-packages.sh` cannot run on a host with no pacman, and `pacman -Si`
cannot see an AUR package at all — asking it about one produces a "target not found" that looks
exactly like a wrong name.

Both are reported as skips, out loud, and neither is counted as verified. The exit status covers
only what was actually checked. This matters more than it sounds: a verification script's whole
value is that a green run means something, and the fastest way to destroy that is to let an
environment that cannot check anything report success.

The AUR case has a second edge that the catalogue is already shaped around: `pacman -S` fails the
**whole transaction** on an unknown name, so one AUR entry on the pacman list takes every unrelated
package in the same converge down with it. That is why `lib/creative.nix` carries an `aur` flag and
the module publishes two lists rather than one.

## Dated observations

From a run on **2026-08-20**, on a host with no pacman — so the pacman half is *skipped, not
verified*. Every catalogued nixpkgs attribute forced against this flake's locked nixpkgs:

| Entry | Attribute | Forced to |
|---|---|---|
| `3d/blender` | `blender` | `blender-5.2.0` |
| `daw/qtractor` | `qtractor` | `qtractor-1.6.2` |
| `raster/krita` | `krita` | `krita-6.0.2.1` |
| `vector/inkscape` | `inkscape` | `inkscape-1.4.4` |

Versions are what the locked input happened to hold that day and are not a claim about anything.
The result that matters is that four of four forced rather than threw.
