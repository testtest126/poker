# Game-Type Formats

Source: `PokerKit/Sources/PokerKit/GameFormat.swift`. Tests:
`GameFormatTests.swift`. Feeds `PushFoldRange`/`OpeningRange`/`CallingRange`/
`ThreeBetRange`/`FourBetRange` (via `effectiveStackBB`), `BountyEquity` (via
a seed `bountyBB`), and `ICMRiskPremium` (whether to surface it at all) — as
**defaults only**. See "What this is (and isn't)" below before wiring
anything else up to it.

## What it does

A `GameFormat` names a tournament/cash **shape** — regular MTT, turbo, hyper-
turbo, PKO (bounty), satellite, cash — and `GameFormatProfile` carries the
tuning values every other tool in this codebase already understands:
starting-point effective stack, whether antes are the sensible assumption,
whether the bounty overlay should default on, whether/how much the ICM-aware
UI should lean in, and blind-level speed.

## What this is (and isn't)

**This is design judgment, not ground-truth math or a transcribed source.**
Contrast with the rest of this codebase's docs:

- `ICM.md` validates exact numbers against a published worked example — there's
  a right answer, and the code either matches it or doesn't.
- `RANGES.md` transcribes specific cited percentages (PokerCoaching.com's GTO
  charts, cardfight.com equity figures) and flags exactly which numbers are
  sourced vs. hand-tuned extrapolation.
- `FORMATS.md` has **no source to cite**. "What's a sensible default starting
  stack for a hyper-turbo" isn't a fact with a right answer the way "what's
  AA's equity vs. KK" is — it's a judgment call about what's typical enough
  to be a useful starting point. Every value below is disclosed as exactly
  that: this project's own choice, not a transcription, not solver output,
  and not defended as more "correct" than a different reasonable choice
  would be.

**This is a defaults/seed layer, not a mutation.** No model this profile
feeds (`PushFoldRange`, `OpeningRange`, `CallingRange`, `ThreeBetRange`,
`FourBetRange`, `BountyEquity`, `ICM`, `ICMRiskPremium`) reads a `GameFormat`
or a `GameFormatProfile` — none of them even import knowledge that formats
exist. A caller (the app) reads a profile *once*, at the moment a user picks
a format, to pre-fill a stack slider / flip a toggle / seed a bounty-size
field — ordinary starting values for parameters those tools already take.
Nothing here clamps, overrides, or re-checks a value after the user has
touched it; picking "Hyper-Turbo MTT" and then manually setting the stack
slider to 80bb produces exactly the same downstream behavior as if the user
had started from any other format and typed 80bb — the format choice only
ever pre-fills, it never constrains.

## The format table

| Format | Default stack | Ante | Bounty | ICM | ICM weight | Speed |
| --- | --- | --- | --- | --- | --- | --- |
| Regular MTT | 100bb | Yes | No | Yes | 0.5 | Regular |
| Turbo MTT | 50bb | Yes | No | Yes | 0.5 | Turbo |
| Hyper-Turbo MTT | 20bb | Yes | No | Yes | 0.5 | Hyper |
| PKO (Bounty) | 100bb | Yes | **Yes** (33% of stack) | Yes | 0.4 | Regular |
| Satellite | 100bb | Yes | No | Yes | **0.9** | Turbo |
| Cash Game | 100bb | No | No | **No** | 0 | — |

### Rationale, value by value

- **Regular MTT — 100bb default stack.** Matches this codebase's own
  existing "standard stack" anchor (`OpeningRange`/`ThreeBetRange`/
  `FourBetRange` all treat 100bb as their reference depth — see `RANGES.md`),
  so a format-driven default doesn't introduce a second opinion on what
  "standard" means.
- **Turbo — 50bb, Hyper — 20bb.** Not measured from any specific turbo
  structure's actual starting stack (turbo structures vary a lot by site and
  buy-in) — chosen so the three MTT speeds form a sensible descending
  sequence, with Hyper landing right at the edge of `PushFoldRange`'s own
  1–20bb comfort zone: the qualitative claim being encoded is "hyper-turbos
  are, for practical purposes, push/fold from early on," which this default
  makes literally true for a user who takes the pre-fill as-is.
- **Ante present — true for every tournament format, false for cash.**
  Modern MTTs (at essentially every speed and stake) run antes throughout;
  standard cash games typically don't. **This value doesn't feed any model
  yet** — no tool in this codebase takes an ante-size parameter (the same
  honestly-disclosed gap `BOUNTY.md` already notes for pot-size inputs) — it's
  carried here so a future ante-aware model has a format-level default
  ready to read, not because something currently consumes it.
- **Bounty enabled — only PKO, at 33% of starting stack.** The 33% figure
  isn't a new guess: it's the exact number already used as a worked example
  in `BountyEquity`'s own doc comment ("50% of the buy-in funds the bounty
  pool, worth ~33% of a starting stack"). Reusing it here means there's still
  only one "typical PKO bounty size" opinion in this codebase, not two.
- **ICM enabled — every format except cash.** Cash chips are literally cash;
  there's no payout-jump structure for ICM to model at all, so `icmEnabled:
  false` isn't a judgment call so much as a category fact. Every tournament
  format, even ones that don't obviously feel "ICM-heavy" (a hyper-turbo
  bubble is still a bubble), defaults to ICM-aware — a user can always ignore
  the ICM UI a format surfaces, but a format silently hiding it would be the
  worse default.
- **ICM weight** is an ordinal 0–1 signal (see `GameFormatProfile.icmWeight`'s
  doc comment) — how hard a format's typical payout shape should nudge a
  user toward caution, comparable only to other formats' values, not backed
  by a formula:
  - **Satellite — 0.9, the highest of any format.** A satellite's whole
    prize structure is binary: every awarded seat is worth the same, so
    "make the cutoff" is close to the entire goal, and min-cash ≈ survival
    in a much starker sense than a payout-jump in a regular MTT. This is the
    clearest, least-arguable case for leaning hard on ICM of any format
    modeled here.
  - **Regular/Turbo/Hyper MTT — 0.5, all equal.** The default position:
    moderate ICM emphasis, heaviest in practice near an actual pay jump.
    Deliberately **not** varied by speed — how fast the blinds climb changes
    stack depth and how soon push/fold territory arrives, but it doesn't
    change the *shape* of the payout structure itself, which is what ICM
    pressure actually responds to. Making Hyper's weight lower than
    Regular's "because it's faster" would be conflating two different axes;
    this project chose not to invent an unjustified distinction here.
  - **PKO — 0.4, lower than a same-sized regular MTT.** A disclosed,
    debatable judgment call, not a citation: PKO strategy discussion
    commonly notes that a collectible bounty gives a reason to get chips in
    looser than chip-EV/ICM alone would suggest (the same tension
    `BOUNTY.md`'s "Scope and honest limitations" section already describes
    as "two competing forces" — bounty-equity widening vs. ICM-style
    tightening). Setting PKO's default ICM weight a notch below Regular's is
    this project's attempt to reflect that those two forces partially cancel,
    not a claim about the exact magnitude.
- **Speed** — `Regular`/`Turbo`/`Hyper` map directly from the three MTT
  format names; **PKO defaults to `Regular`** (bounty tournaments run at
  every speed in practice — Regular is simply the most common "classic PKO"
  cadence, not a claim that PKOs are never turbo); **Satellite defaults to
  `Turbo`** (single-day satellites are very commonly turbo-structured to fit
  a shorter overall time commitment); **Cash is `nil`** — cash games don't
  have blind levels, so "speed" is category-inapplicable, not unknown.

## Tests: internal consistency, not external truth

`GameFormatTests.swift` cannot and does not claim these numbers are
"correct" the way `ICMTests` can for ICM math — there's no ground truth to
check against. What it checks instead:

- The format list is exhaustive and stable (`GameFormat.allCases` is exactly
  the 6 documented cases).
- Every format round-trips through both `rawValue` and `Codable`.
- `pko.bountyEnabled == true` and is the *only* format with it on.
- `cash.icmEnabled == false && cash.bountyEnabled == false`.
- `satellite.icmWeight` exceeds every other format's.
- `pko.icmWeight < mttRegular.icmWeight` (the bounty-offsets-ICM judgment
  call above, locked in as a regression check).
- Default stack depth strictly decreases Hyper < Turbo < Regular.
- `defaultBountyFractionOfStartingStack` is set if and only if
  `bountyEnabled` is true; `speed` is `nil` if and only if the format is
  `.cash` — structural invariants, not opinions.

## Consumers

- Planned: a format picker in the app (a global setting the range/push-fold/
  ICM/bounty screens read to pre-fill their own existing controls) — see the
  app's `StudyTool` list / a settings area.
