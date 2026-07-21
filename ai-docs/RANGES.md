# Preflop Ranges

Source: `PokerKit/Sources/PokerKit/ChenScore.swift`, `PushFoldRange.swift`,
`OpeningRange.swift`, `CallingRange.swift`, `PushFoldSpot.swift`,
`Position.swift`. Tests: `ChenScoreTests.swift`, `PushFoldRangeTests.swift`,
`OpeningRangeTests.swift`, `CallingRangeTests.swift`.

Four range models live here, covering both sides of a preflop decision across
two stack regimes of an MTT:

- **Push/Fold** (`PushFoldRange`) — short stacks, roughly 1–20bb, hero is the
  aggressor: shove-or-fold.
- **Opening / raise-first-in** (`OpeningRange`) — standard stacks, roughly
  20–100bb, hero is the aggressor: raise-or-fold. Covers the part of a
  tournament before the stack gets short enough for push/fold to take over.
- **Facing a shove** (`CallingRange.decideVsShove`) — short stacks, hero is
  *defending*: call-or-fold against someone else's shove.
- **Facing an open** (`CallingRange.decideVsOpen`) — standard stacks, hero is
  *defending*: fold, call, or 3-bet against someone else's open-raise.

All four are **hand-tuned study aids, not solver output** — see each section
below for what "hand-tuned" means and where the numbers come from. The two
defending models are meaningfully less certain than the two aggressor models
— see "Facing a shove" and "Facing an open" below for exactly why, and which
parts of each to trust least.

`PushFoldRange` also has an optional PKO **bounty-adjusted** overlay —
`BountyEquity` — that widens its shove percentage when hero covers a bountied
villain, without modifying `PushFoldRange` itself. See **[BOUNTY.md](BOUNTY.md)**
for the formula and its sources; not repeated here since it's a layer on top
of this document's models, not a third one.

## Push/Fold

An **unopened-pot, short-stack push/fold decision**: hero is first to act (or
everyone before them folded), effective stack is roughly 1–20bb, and the only
two options the model considers are shove-all-in or fold — no limping, no
min-raising. This is the classic late-MTT short-stack spot.

**This is a hand-tuned study aid, not solver output.** Real Nash/ICM-optimal
push/fold ranges come from equilibrium computation (HoldemResources
Calculator, ICMIZER, etc.) that accounts for exact stack sizes, payout
structure, and every opponent's stack. `PushFoldRange` instead encodes the
general *shape* of published unopened shove charts — tighter early position,
much wider on the button/small blind, wider as the stack gets shorter — using
a hand-picked percentage table. The doc comment on `PushFoldRange` is explicit
about this and about how to upgrade it later (swap `shovePercentByPosition`
for solved numbers, or a full per-hand lookup table — nothing downstream
changes).

### The pipeline

1. **`ChenScore.score(for: HoleCards) -> Double`** — Bill Chen's published
   hand-strength heuristic. Ranks the 169 starting hands without hand-typing
   169 equity numbers:
   - High card score (A=10, K=8, Q=7, J=6, T=5, else rank/2)
   - Pairs: double the high-card score, minimum 5
   - +2 if suited
   - Gap penalty between the two ranks: 0/1/2/3/4+ → −0/−1/−2/−4/−5
   - +1 if gap ≤ 1 and the high card is below queen (straight potential)
   - A half-point score rounds *up* (Chen's rule — `roundHalfUp`)

2. **`PushFoldRange.shovePercentage(position:effectiveStackBB:)`** — looks up
   `shovePercentByPosition[position]`, a table of shove-% at 10 stack
   breakpoints (`[1, 2, 3, 5, 7, 10, 12, 15, 17, 20]` bb), and linearly
   interpolates between breakpoints (clamped to `[1, 20]`).

3. **`PushFoldRange.scoreThreshold(forPercentage:)`** — ranks all 169 canonical
   hands by Chen score (`rankedCanonicalScores`, computed once, sorted
   descending) and returns the Chen score at the requested percentile. This is
   what turns "shove the top 22%" into an actual score cutoff.

4. **`PushFoldRange.decide(hand:position:effectiveStackBB:) -> PushFoldDecision`**
   — combines the three: percentage from position+stack, threshold from that
   percentage, hero's own Chen score, and shoves if `handScore >= threshold`.
   `PushFoldDecision.reasoning` renders a one-line explanation for the trainer
   UI ("Hand strength score 9 clears the shove threshold of 7 (top 22% of
   hands)...").

### `PushFoldSpot`

A dealable drill spot: `hand: HoleCards`, `position: Position`,
`effectiveStackBB: Int`. `.decision` computes the `PushFoldDecision` on
demand. `.random(using:)` deals uniformly across all positions and 1–20bb —
this is what the plain Push/Fold Trainer screen (`PushFoldTrainerView`) uses;
`DrillGenerator` (see `DRILLS.md`) biases the same primitive toward a user's
own leak region instead of sampling uniformly.

## Opening (Raise-First-In) Ranges

An **unopened-pot, standard-stack opening decision**: hero is first to enter
the pot, effective stack is roughly 20–100bb, and the model considers
raise-first-in vs. fold (no limping — consistent with the push/fold model's
own no-limp scope). This is the preflop decision that covers most of an MTT
before the stack gets short.

**This is also a hand-tuned study aid, not solver output**, same posture and
same reason as `PushFoldRange`: real GTO-solved opening ranges depend on exact
stack depths, ante structure, rake, opponent tendencies, and postflop
strategy that a static table can't capture. `OpeningRange` reuses the exact
same pipeline as `PushFoldRange` — `ChenScore` for hand ranking and
`PushFoldRange.scoreThreshold(forPercentage:)` for turning a percentage into a
score cutoff — so there is still only one hand-ranking system in this
codebase. The only new thing `OpeningRange` introduces is its own
`openPercentByPosition` table and 3 stack breakpoints (`[20, 40, 100]` bb,
vs. push/fold's 10) — fewer breakpoints because the source material backing
this table is thinner across stack depths (see "Source basis" below).

### Source basis — read this before trusting a specific number

The 100bb column is the only one backed by a full, named, position-by-position
source. The 40bb and 20bb columns are **hand-tuned extrapolations**, not
independently sourced charts. Per this project's own rule (bad poker math is
worse than none), here's exactly what's sourced vs. extrapolated:

- **100bb anchor (sourced).** PokerCoaching.com's "Implementable GTO Charts"
  for 6-max, 100bb (a GTO-solver output with mixed strategies removed for
  single-action clarity) — cross-verified by fetching it directly twice via
  two different page paths, both times returning the identical numbers:
  UTG 10.1%, LJ 17.6%, HJ 21.4%, CO 27.8%, BTN 43.5%, SB 62.3%.
  (`poker-coaching.s3.amazonaws.com/tools/preflop-charts/online-6max-gto-charts.pdf`,
  via `pokercoaching.com/preflop-charts/`.) Rounded to whole percentages for
  the shipped table: UTG 10, MP(LJ) 18, HJ 21, CO 28, BTN 43.

- **SB is deliberately tightened below its cited source.** The 62.3% SB
  figure above is real and reproducible, but a second independent source
  (freebetrange.com's 6-max open-raise chart) puts SB open-raising at 39–47%
  for broadly the same context — a large enough disagreement between two
  reputable sources that we treat SB as genuinely uncertain rather than
  picking whichever number sounds more authoritative. Per this project's
  "err tight, note the uncertainty" rule, the shipped table uses **45%**
  (the conservative end of the second source's range) rather than the raw
  62.3% GTO figure. This is a deliberate, disclosed choice, not a rounding
  error — if you find a better-corroborated number, `openPercentByPosition`
  is a one-line change. The qualitative fact the sourced data agrees on (SB
  opens wider than BTN, since SB is only playing past one opponent) is kept;
  only the magnitude is pulled in.

- **40bb column (single-anchor extrapolation).** The only concrete 40bb data
  point found was UTG ≈ 13% (Preflop Wizard's MTT preflop-strategy write-up),
  vs. the sourced 100bb UTG figure of 10.1% — a +3-point widening. Every
  position's 40bb number in the shipped table is the 100bb number plus that
  same +3-point offset. This is explicitly an extrapolation from one data
  point, not six independently sourced ones. It's directionally consistent
  with every source found (ranges widen as tournament stacks shorten, largely
  because of increasing ante pressure), but the exact magnitude for
  positions other than UTG is a hand-tuned guess, not a citation.

- **20bb column (hand-tuned extrapolation, no direct source).** No source
  with concrete 20bb 6-max opening percentages was found. The shipped table
  uses the 100bb number plus a +6-point offset (double the 40bb offset),
  consistent with the qualitative direction every source agrees on (ranges
  widen further as the stack approaches push/fold territory) but with no
  citation backing the specific number. Treat the 20bb column as the least
  trustworthy part of this table — it exists mainly so the slider has a
  smooth floor right where `PushFoldRange` picks up, not because it's
  independently verified. **This model and `PushFoldRange` are not
  reconciled at that boundary** — they're two separate hand-tuned tables, so
  don't expect their numbers to line up exactly at 20bb.

If you want to firm any of this up: replace `openPercentByPosition` with a
properly-sourced chart per breakpoint (ideally the same source across all
positions and all three depths) — nothing downstream changes, same upgrade
path `PushFoldRange` already documents for itself.

### The pipeline

Identical shape to push/fold's, with `OpeningRange` in place of
`PushFoldRange`:

1. `ChenScore.score(for:)` — same hand ranking, no changes.
2. `OpeningRange.openPercentage(position:effectiveStackBB:)` — looks up
   `openPercentByPosition[position]` at breakpoints `[20, 40, 100]` bb,
   linearly interpolates, clamped to `[20, 100]`.
3. `PushFoldRange.scoreThreshold(forPercentage:)` — reused directly, not
   duplicated.
4. `OpeningRange.decide(hand:position:effectiveStackBB:) -> OpeningDecision`
   — raises if `handScore >= threshold`. `OpeningDecision.reasoning` mirrors
   `PushFoldDecision.reasoning`'s wording, swapped to "open-raise threshold."

## Facing a Shove

An **all-in call/fold decision**: someone has already shoved (modeled as
coming from a specific `Position`, roughly 1–20bb effective), and `caller` —
a `DefendingPosition`, which unlike `Position` includes the big blind — has
to decide whether to call it off or fold. No 3-betting; once someone's
all-in, calling is the only "continue" option.

**This is a hand-tuned study aid, and the least certain model in this file
after "Facing an open."** Read this before trusting a specific number:

- **What's actually well-documented:** the pure heads-up case — small blind
  shoves, big blind calls — has a widely-published Nash equilibrium (see
  e.g. HoldemResources.net's and GTOCharts.com's heads-up Nash push/fold
  charts). Multiple sources are explicit that this is *the only* case with a
  standard, independently-computed answer: calling charts for anyone other
  than the big blind, against a shove from anyone, don't have an equivalent
  public standard — those genuinely require a solver run for the exact
  stacks and payout structure in play.
- **What this model does about that:** rather than inventing position-by-
  position numbers with false precision, `CallingRange` derives calling
  percentages from a number already in this codebase —
  `PushFoldRange.shovePercentage(position:effectiveStackBB:)`, the shover's
  own modeled range width — discounted by two factors:
  1. **`shoveDiscountByStack`** — calling requires real showdown equity, not
     just fold equity, so the profitable call% at a given stack is always a
     fraction of the shove% at that stack, and that fraction shrinks as the
     stack deepens (there's more room to be dominated, and less desperation
     pressure). The curve (0.90 at 1bb down to 0.38 at 20bb) is a hand-tuned
     approximation, calibrated against the one concrete external number
     found: a heads-up Nash small-blind shove figure of **~50% at 10bb**
     (via web search of published heads-up Nash summaries), compared against
     this project's own `PushFoldRange` SB shove figure of **58% at 10bb** —
     close enough that treating them as the same underlying phenomenon (a
     6-max-context table vs. a pure-heads-up one) is a reasonable, disclosed
     assumption rather than a citation.
  2. **`callerPositionDiscount`** — a further, *unsourced* discount for every
     caller besides the big blind. The big blind is the only calling
     position that's genuinely equivalent to the heads-up Nash case (it
     always closes the action). The small blind gets a worse price (half a
     blind posted, not a full one) and non-blind callers risk a player still
     to act behind them waking up with a hand (squeeze risk) — both real,
     commonly-cited reasons real ranges there are narrower, but no source
     gives a magnitude for either. **Treat every non-big-blind number in this
     model as a rough placeholder, not a considered chart.**

`caller.actionOrderIndex > shover.actionOrderIndex` is required (see
"Positions modeled" below) — `callPercentage`/`decideVsShove` return `nil`
for pairings that can't happen at an unopened table (e.g. UTG can't be
"facing" anyone's shove; nobody can face their own).

### The pipeline

1. `PushFoldRange.shovePercentage(position: shover, ...)` — the shover's own
   modeled range width, reused rather than re-derived.
2. `shoveDiscount(effectiveStackBB:)` — the stack-only discount curve above,
   interpolated the same way `PushFoldRange`/`OpeningRange` interpolate their
   own breakpoint tables.
3. `callerPositionDiscount[caller]` — the position-only discount above.
4. `callPercentage` multiplies all three (clamped to `[0, 100]`).
5. `PushFoldRange.scoreThreshold(forPercentage:)` — reused directly, same as
   `OpeningRange`.
6. `decideVsShove` calls if `handScore >= threshold`.

## Facing an Open

A **fold/call/3-bet decision**: someone has open-raised (modeled as coming
from a specific `Position`, roughly 20–100bb effective), and `defender` — a
`DefendingPosition` — has to decide whether to fold, flat-call, or 3-bet.

**This is also a hand-tuned study aid, and this file's least certain model.**
No position-by-position sourced chart for defending ranges (as opposed to
opening ranges, which do have one — see "Opening" above) was found at all;
everything here is derived from one sourced anchor plus qualitative,
commonly-repeated MTT strategy principles:

- **The one sourced anchor:** big blind's combined call+3-bet continuing
  frequency against a standard button open is commonly cited at **~84%**
  (found via web search of MTT preflop-strategy material discussing big
  blind defense — a "defend almost everything, since suited hands are
  essentially never a fold for the big blind" figure that shows up
  repeatedly across sources, alongside the well-known qualitative shorthand
  that big blind's *offsuit* defend boundary tightens by opener position,
  e.g. down to the 5-high offsuit hands vs. a button open, the 6-high
  offsuit hands vs. a cutoff open, and so on for earlier opens). This is the
  only number in "Facing an open" backed by an external figure rather than
  pure extrapolation.
- **Every other position/opener combination is derived from that one
  anchor**, scaled by the ratio of `OpeningRange.openPercentage(opener:)` to
  `OpeningRange.openPercentage(.button:)` at the same stack — i.e. "the big
  blind should defend against a given opener's range roughly in proportion
  to how wide that opener actually opens, relative to how wide a button
  open is." This reuses `OpeningRange`'s own already-disclosed numbers
  (including its own uncertain columns — see "Opening" above) rather than
  inventing a second, independent opinion about how wide each position
  opens.
- **Small blind's total defense** is set to **65%** of what the big blind
  would defend against the same open — every source found agrees small
  blind defends narrower than big blind (worse price: half a blind posted,
  not a full one; out of position the rest of the hand against everyone but
  the button), but none gives an exact ratio. Hand-tuned.
- **Non-blind defenders** (someone still to act behind the opener, not in
  the blinds — e.g. the cutoff facing an under-the-gun open) get a flat
  **50%** of what the big blind would defend. **This is the single
  least-confident number in this entire file.** No source distinguishing,
  say, "hijack facing a UTG open" from "button facing a cutoff open" was
  found — this model treats every non-blind defending position identically,
  which is certainly wrong in degree even if the direction (tighter than
  the blinds, since there's no sunk blind investment) is reasonable.
- **The call/3-bet split** within total defense: big blind's is set to 25%
  3-bet / 75% call, small blind's to 45% 3-bet / 55% call (small blind is
  documented in multiple sources as leaning more toward "3-bet or fold,"
  avoiding cold-calls that play badly out of position against a raise), and
  non-blind defenders to 35% 3-bet / 65% call as a middling, unsourced
  guess. **A real 3-betting range is polarized** — strong value hands *and*
  bluffs with blockers/playability. Ranking purely by Chen score and taking
  the top slice as "3-bet" only ever captures the value half of that; this
  model has no bluff-3-bet concept at all. Disclosed simplification, not an
  oversight.

If you want to firm any of this up: a real position-by-position, stack-aware
defending chart (ideally covering blind defense and non-blind defense
separately, the way opening charts already do) would let
`totalDefensePercentage` and `threeBetShare` be replaced outright — nothing
downstream changes, same upgrade path every other model in this file
documents for itself.

### The pipeline

1. `OpeningRange.openPercentage(position: opener, ...)` and
   `OpeningRange.openPercentage(position: .button, ...)` — reused, not
   re-derived.
2. `totalDefensePercentage` — the big blind anchor (84%) scaled by that
   ratio, then by the defender-position factor (1.0 / 0.65 / 0.5) above.
3. `threeBetShare(of: defender)` — the unsourced call/3-bet split above.
4. `PushFoldRange.scoreThreshold(forPercentage:)` — reused twice: once for
   the overall defend threshold, once for the (narrower) 3-bet threshold.
5. `decideVsOpen` — 3-bets at or above the 3-bet threshold, calls at or
   above the defend threshold, folds below it.

## Positions modeled

`Position` (`UTG, MP, HJ, CO, BTN, SB`) deliberately **excludes the big
blind** — if action folds all the way around, BB has already won the pot
uncontested, so there's no opening or push/fold decision to make there.
`DefendingPosition` (`UTG, MP, HJ, CO, BTN, SB, BB`) is the position type for
the two *defending* models above — it adds the big blind back in, since a
defending hero can be exactly the player who was excluded from `Position`.
Both enums declare their shared six cases in identical order, so
`Position.actionOrderIndex`/`DefendingPosition.actionOrderIndex` (private
helpers in `CallingRange.swift`) are directly comparable: a defender is only
ever facing a valid shove/open if `defender.actionOrderIndex >
shover.actionOrderIndex` — i.e. the defender genuinely acts after the
aggressor at an unopened table. `callPercentage`, `totalDefensePercentage`,
`decideVsShove`, `decideVsOpen`, and their `PreflopGrid` equivalents all
return `nil` rather than a nonsensical decision when that's violated.

## Consumers

- `PushFoldTrainerView` — plain random push/fold practice.
- `PreflopGrid` (`PREFLOP-GRID.md`) — renders `PushFoldRange.decide` (via
  `decisions`), `OpeningRange.decide` (via `openingDecisions`),
  `CallingRange.decideVsShove` (via `callingDecisions`), and
  `CallingRange.decideVsOpen` (via `openDefenseDecisions`) for all 169 hands
  at once as a grid; `PreflopRangeView` switches between all four with a
  mode control.
- `LeakAnalysisEngine` (`LEAK-ANALYSIS.md`) — compares hero's actual
  imported-hand decisions against `PushFoldRange.decide` to find deviations.
  Still push/fold-only; opening-range and defending-range adherence are not
  tracked.
- `DrillGenerator` (`DRILLS.md`) — deals `PushFoldSpot`s weighted toward those
  deviations. Still push/fold-only.

Within each model there is exactly one implementation — every consumer of a
given model calls through that model directly, so there's never a second
opinion on what "correct" means for a given spot. The four models themselves
are intentionally separate (different stack regimes, different roles,
different source basis, different confidence level) rather than one model
trying to cover everything. `CallingRange`'s two halves in particular reuse
`PushFoldRange`/`OpeningRange`'s own numbers rather than re-deriving
anything — there's exactly one "how wide does this position shove/open"
opinion in the codebase, and both defending models scale off it.
