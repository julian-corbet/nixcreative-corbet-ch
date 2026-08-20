# What surveying open speech models taught the catalogue

Twelve models were surveyed to decide what the cluster plane's voice tier should serve and what a
catalogue of speech models would have to record to make that decision again later. The survey ran
as two independent passes over the same ground: one proposing candidates from practice, one
re-deriving every fact from a primary source — a model card, a licence text, or a hub or repository
API — and reporting where the two came apart.

The models are in [`lib/voices.nix`](../lib/voices.nix) and the candidates that could not be
established are in [`experiments/open-questions.md`](../experiments/open-questions.md). This is
what the exercise changed.

## The finding that set the field list

**An open-source licence on the code and a non-commercial licence on the weights is a normal shape,
not an anomaly.** Two of the twelve carry it, and it is the shape a careful reader still gets wrong,
because the open half is the half that gets quoted.

The worst case in the set: a model whose card says, in one sentence, that the code is Apache-2.0
and the pre-trained weights are CC-BY-NC because of a constraint inherited from the training data.
The hub carries **no licence tag at all** on that repository. So there are three ways to be wrong
about it and all three are cheap:

- read the sentence quickly and carry "Apache-2.0" away from it;
- key on the repository's licence tag, find nothing, and record it as unlicensed;
- take the code's licence as the model's, which is the default assumption everywhere else.

That model was proposed in the first pass as the answer to "we want more languages", with no licence
caveat attached — which is exactly how it would have arrived in a catalogue.

The second one is quieter and older: a model still downloaded in enormous volume, whose weights are
under a bespoke non-commercial licence while the maintained fork that serves them is MPL-2.0. Read
the serving code's licence and stop there, and you have the answer exactly backwards.

Three consequences, all of them visible in the file:

1. **`commercialUse` is a judgement, not a boolean.** `yes`, `no`, `conditional` — the third for a
   licence that permits commercial use while binding what you may do with the model, which a
   boolean would have to round in one direction or the other. Both roundings are wrong.
2. **Anything other than `yes` must carry a `caveat`.** Enforced in
   [`checks/voices-eval.nix`](../checks/voices-eval.nix), so a restriction cannot be recorded as a
   bare enum value that nobody can act on.
3. **`licence.name` is prose and `licence.spdx` is optional.** A two-instrument stack — a model
   under one licence depending on a codec under another — has no identifier, and forcing one would
   mean picking the friendlier half. Two entries are in that position; both have `spdx = null`.

## The finding that put `unverified` in the schema

A parameter count is the field most likely to be *approximately* known: stated in a paper but not on
the card, stated for a family rather than a checkpoint, or not stated anywhere and inferrable from
the size of a download. Every one of those is a plausible-looking number, and a plausible-looking
number is indistinguishable from a sourced one once it is written down.

So the file has no way to write one down quietly. A fact the sources do not establish is `null`,
**and** the entry must name the field in `unverified` with what would have to be fetched. The check
enforces both directions, and the second direction is the load-bearing one: naming a field that is
NOT null is also an error, which is what stops a "we never checked this" note outliving the
checking. Four fields across three models are in that state today.

## The finding that removed a field

**One model card serves a whole model family, and its language list belongs to one member of it.**
The card for a family whose smallest member is catalogued here lists 23 languages — for the 500M
multilingual sibling. The model-zoo table on that same card puts the small one at 110M and English.
Read top to bottom, the card attributes the list to whichever model you were looking up; the second
research pass reported making that error before catching it against the table.

The two passes therefore disagreed about the language coverage of a model that was one pass's
leading recommendation. The rule for a disagreement is that it is recorded and the field is left
out, and that is what happened: **there is no `languages` field in the catalogue.** It was never
one of the five facts that decide a deployment — scale, device, cloning, licence, provenance are —
and a survey that produced a demonstrated error on its first use is not evidence a sixth field was
needed. The trap itself is recorded in the entry's `note`, where somebody re-reading that card will
meet it.

## The finding that split `gated` from its enforcement

The survey recorded one model as gated behind an explicit "non-commercial use ONLY" checkbox, and
noted the mechanical consequence: an unattended fetcher would need an authenticated token.

Running [`experiments/verify-voices.sh`](../experiments/verify-voices.sh) against the hub on
**2026-08-20** found the first half true and the second half not:

- the card declares the agreement, including that checkbox, in its gate fields;
- the hub's own `gated` flag on that repository reads **false**;
- an anonymous request for a file in it is answered with a **307** redirect to the CDN, not a 401.

Both observations are correct and they are about different things. So `gated` now means **the
weights are published behind terms you must accept** — a property of the release — and whether the
hub is enforcing them today is reported by the script as a separate, movable observation. The
catalogue's caveat was corrected: the agreement is what binds, and the wall is not currently up.

This is also why the script compares the *declared* gate and not the flag. A comparison against the
flag would have failed on a model whose terms had not changed at all.

## The finding that made the script read ids rather than status codes

Two id hazards, both cheap to hit and neither visible as an error:

- **A renamed repository keeps answering.** One catalogued model's vendor blog still links its old
  id, which redirects rather than 404s. A fetcher following the blog gets weights; a reader copying
  the blog records a name that is no longer canonical. The script therefore compares the id the API
  *answers with* against the catalogued one, rather than checking that the request succeeded.
- **401 does not distinguish "gated" from "does not exist".** Two plausible ids for a multilingual
  variant both answered 401, which is why that variant is an open question rather than an entry.
  There is no way to tell those two cases apart from outside, and a catalogue that guessed would be
  publishing a repository id nobody can fetch.

## Dated observations

Everything in this section moves, which is why none of it is in the catalogue. From a full run of
`experiments/verify-voices.sh` on **2026-08-20**, every catalogued model's id, licence tag and gate
matched what was recorded. Upstream activity, from the same run:

| Model | Upstream last pushed | Archived |
|---|---|---|
| `omnivoice` | 2026-08-17 | no |
| `voxcpm2` | 2026-08-12 | no |
| `fish-s2-pro` | 2026-08-03 | no |
| `supertonic-3` | 2026-07-24 | no |
| `chatterbox`, `chatterbox-nano` | 2026-07-21 | no |
| `gepard-1.0` | 2026-07-06 | no |
| `xtts-v2` (maintained fork) | 2026-06-10 | no |
| `higgs-tts-3` | 2026-06-05 | no |
| `qwen3-tts-0.6b` | 2026-03-17 | no |
| `kokoro-82m` | 2025-08-06 | no |
| `bark` | 2024-08-19 | no |

Two of those are worth a second look and both are already in the file's notes. `bark`'s upstream
has not moved in two years, which is the reason its entry exists at all — it stays findable through
a mainstream library long after it stopped being a reasonable choice. `kokoro-82m`'s upstream had
not moved for a year at the time of the run, which is a fact about the *code*: it is a small model
with a stable serving path, deployed here through a third party's server image rather than through
that repository, and the model is what this repository serves. Worth watching, not worth acting on.

## What is not recorded

The second research pass flagged further corrections to the first pass's recommendations. Two were
legible in the material this catalogue was built from and are recorded above; the rest were not, and
they are deliberately not summarised or guessed at here. A half-remembered correction is worse than
an absent one — it reads as settled and cannot be checked. The procedure for settling any of them
is the same three fetches as everything else, in
[`experiments/open-questions.md`](../experiments/open-questions.md).
