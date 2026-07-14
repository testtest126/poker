# Push/Fold Ranges

Source: `PokerKit/Sources/PokerKit/ChenScore.swift`, `PushFoldRange.swift`,
`PushFoldSpot.swift`, `Position.swift`. Tests: `ChenScoreTests.swift`,
`PushFoldRangeTests.swift`.

## What this models

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

## The pipeline

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

## Positions modeled

`Position` (`UTG, MP, HJ, CO, BTN, SB`) deliberately **excludes the big
blind** — if action folds all the way around, BB has already won the pot
uncontested, so there's no push/fold decision to make there. A BB facing an
earlier shove is a *calling* range, a different (and currently unmodeled)
tool. See `Position.swift`'s doc comment.

## `PushFoldSpot`

A dealable drill spot: `hand: HoleCards`, `position: Position`,
`effectiveStackBB: Int`. `.decision` computes the `PushFoldDecision` on
demand. `.random(using:)` deals uniformly across all positions and 1–20bb —
this is what the plain Push/Fold Trainer screen (`PushFoldTrainerView`) uses;
`DrillGenerator` (see `DRILLS.md`) biases the same primitive toward a user's
own leak region instead of sampling uniformly.

## Consumers

- `PushFoldTrainerView` — plain random practice.
- `PreflopGrid` (`PREFLOP-GRID.md`) — renders `PushFoldRange.decide` for all
  169 hands at once as a grid.
- `LeakAnalysisEngine` (`LEAK-ANALYSIS.md`) — compares hero's actual
  imported-hand decisions against `PushFoldRange.decide` to find deviations.
- `DrillGenerator` (`DRILLS.md`) — deals `PushFoldSpot`s weighted toward those
  deviations.

There is exactly one push/fold model in the codebase; every screen and the
leak-analysis engine all call through `PushFoldRange`, so there's never a
second opinion on what "correct" means for a given spot.
