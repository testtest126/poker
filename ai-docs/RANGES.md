# Preflop Ranges

Source: `PokerKit/Sources/PokerKit/ChenScore.swift`, `PushFoldRange.swift`,
`OpeningRange.swift`, `PushFoldSpot.swift`, `Position.swift`. Tests:
`ChenScoreTests.swift`, `PushFoldRangeTests.swift`, `OpeningRangeTests.swift`.

Two range models live here, covering two different stack regimes of an MTT:

- **Push/Fold** (`PushFoldRange`) — short stacks, roughly 1–20bb, shove-or-fold.
- **Opening / raise-first-in** (`OpeningRange`) — standard stacks, roughly
  20–100bb, raise-or-fold. Covers the part of a tournament before the stack
  gets short enough for push/fold to take over.

Both are **hand-tuned study aids, not solver output** — see each section
below for what "hand-tuned" means and where the numbers come from.

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

## Positions modeled

`Position` (`UTG, MP, HJ, CO, BTN, SB`) deliberately **excludes the big
blind** — if action folds all the way around, BB has already won the pot
uncontested, so there's no opening or push/fold decision to make there. A BB
facing an earlier shove or raise is a *calling* range, a different (and
currently unmodeled) tool. See `Position.swift`'s doc comment. Both range
models share this same six-position scheme, so `OpeningRange` introduces no
new position taxonomy.

## Consumers

- `PushFoldTrainerView` — plain random push/fold practice.
- `PreflopGrid` (`PREFLOP-GRID.md`) — renders `PushFoldRange.decide` (via
  `decisions`) and `OpeningRange.decide` (via `openingDecisions`) for all 169
  hands at once as a grid; `PreflopRangeView` toggles between the two with a
  segmented control.
- `LeakAnalysisEngine` (`LEAK-ANALYSIS.md`) — compares hero's actual
  imported-hand decisions against `PushFoldRange.decide` to find deviations.
  Still push/fold-only; opening-range adherence is not tracked.
- `DrillGenerator` (`DRILLS.md`) — deals `PushFoldSpot`s weighted toward those
  deviations. Still push/fold-only.

Within each model there is exactly one implementation — every consumer of
push/fold calls through `PushFoldRange`, every consumer of opening ranges
calls through `OpeningRange`, so there's never a second opinion on what
"correct" means for a given spot under a given model. The two models
themselves are intentionally separate (different stack regimes, different
source basis, different confidence level) rather than one model trying to
cover both.
