# Open questions

Things that were proposed for a catalogue and are **not in one**, each with what would have to be
established before they could be.

The rule this file exists to enforce is the voice catalogue's own: a model is catalogued only where
two independent researches agreed it exists, or where one did and the primary source URL was
recorded. Everything else lands here. An entry in this file is not a judgement that the thing is
wrong — several of these are probably fine — it is a statement that **nobody in this repository has
fetched the evidence**, and a catalogue entry would therefore be a repetition rather than a fact.

Every id below is quoted as **reported, unconfirmed here**. That distinction is the whole file: a
fabricated repository id is the worst possible outcome of this work, because it looks exactly like
a real one and fails only at the moment somebody tries to use it.

## How to settle one

For a voice model, the evidence is three fetches and they are already scripted:

```sh
curl -sS https://huggingface.co/api/models/<owner>/<name> | jq '{id, gated, cardData}'
curl -sS https://huggingface.co/<owner>/<name>/raw/main/README.md | head -80
curl -sS https://api.github.com/repos/<owner>/<repo> | jq '{archived, pushed_at, license}'
```

The first answers whether the id is canonical (a renamed repository answers with the id it
redirected to), what the hub's licence tag says, and whether an agreement gate is declared. The
second is the only place a parameter count, a device requirement or a cloning claim can be read
from. The third says whether the code that serves it is still moving.

Add the entry to `lib/voices.nix` with its sources, then run `./experiments/verify-voices.sh <key>`
— it will fail immediately if the entry and the hub disagree.

## Voice models reported but not catalogued

Reported by one research pass, with adoption or licence notes but **no primary source URL recorded
in this repository**. Grouped by why they would be worth settling.

| Reported id | Reported as | What has to be established |
|---|---|---|
| `microsoft/VibeVoice-Realtime-0.5B` | a streaming model with a permissive licence and heavy adoption | id, parameter count, licence, whether it clones, whether a CPU path exists |
| `microsoft/VibeVoice-1.5B` | long-form multi-speaker generation, same family | as above, plus whether the family's larger sibling shares the licence |
| `KittenML/kitten-tts-nano-0.2` | an order of magnitude smaller than the smallest catalogued model, CPU-only, no cloning | id, parameter count, licence, and the CPU claim, which is the whole reason to care |
| `OHF-Voice/piper1-gpl` + `rhasspy/piper-voices` | the de-facto CPU voice of the self-hosted world; engine and voices under **different** licences | both licences separately — a copyleft engine with permissively-licensed voices is a two-instrument stack like two catalogued entries already are |
| `IndexTeam/IndexTTS-2.5` | cloning with disentangled emotion control, under a vendor licence whose commercial terms need reading | the licence body above all; a vendor licence is exactly what `commercialUse` exists to record |
| `FunAudioLLM/Fun-CosyVoice3-0.5B-2512` | a permissively-licensed alternative at a scale the catalogue already covers | id (the organisation was reported to have moved), licence, cloning |
| `Qwen/Qwen3-TTS-12Hz-1.7B-*` | a larger and reportedly better-adopted tier of a model that IS catalogued at 0.6B | the ids, which is the only thing separating them from the catalogued sibling |
| `SWivid/F5-TTS` | a flow-matching zero-shot model, actively maintained | everything; nothing about it was verified here |
| `canopylabs/orpheus-3b-0.1-ft` | a speech-LLM with cloning, aging | the id in particular — the hub organisation and the code organisation were reported to differ by one word, which is the classic id error |
| `neuphonic/neutts-air` | on-device CPU model whose **code and weights licences were reported to disagree** | which licence governs the weights; a mismatch is a blocker until it is resolved, not a footnote |

Two general cautions from the same research, worth carrying because they are cheap to hit:

- A model id that returns **401** anonymously is gated *or* absent, and the two are
  indistinguishable from the outside. Neither is grounds for cataloguing an id.
- A repository that answers a **307** is redirecting: the id you asked for resolved, but it is not
  necessarily the canonical one. `verify-voices.sh` compares the id the API answers with rather
  than the one it was asked about, for exactly this reason.

## Facts a catalogued model is missing

These entries ARE catalogued, with the field left `null` and named in `unverified`. Repeated here so
the work is visible in one place; the reason lives in `lib/voices.nix` beside the field.

| Model | Field | What has to be established |
|---|---|---|
| `omnivoice` | `parameters` | the model card states no count. A backbone size appears in the paper; settling it means confirming the released weights are the paper's model rather than assuming the two describe each other. |
| `fish-s2-pro` | `voiceCloning` | the card documents prosody tags and languages and says nothing about zero-shot speaker cloning. The family reportedly supports it, which is an inference. The technical report is where it would be read. |
| `xtts-v2` | `parameters` | stated nowhere; it would have to be read off the released checkpoint's tensor shapes. |
| `xtts-v2` | `needsGpu` | stated in neither direction. It would have to be measured by running the maintained fork on a CPU. |

## A repository id that could not be pinned

`ResembleAI/chatterbox` is catalogued as the English original at 500M. A **multilingual variant at
the same parameter scale** is described on the same model card, and its weights repository id is
not catalogued: two plausible ids were probed and both answered 401, which — see the caution above
— does not distinguish "gated" from "does not exist". A Space exists under that name, and a Space
is not a weights repository.

Settling it means finding the id the serving package itself resolves: the pip package downloads the
weights, so the id is in its source or in its download log, and that is a stronger source than any
amount of searching the hub.

## Not a question, a decision: the package catalogue proposes nothing new

`lib/creative.nix` holds four entries, one per group, and that is a ratified target state rather
than a partial catalogue. The names that were considered and declined are listed in the README
under *Deliberately not proposed*, with the reason each was declined, so that the same candidates
do not return as open questions. This file is not where a package proposal goes.
