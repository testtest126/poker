# Leak Analysis

Source: `PokerKit/Sources/PokerKit/LeakAnalysis.swift`. Tests:
`LeakAnalysisTests.swift`. Consumed by `app/Sources/LeakAnalysisView.swift`
("Leak Finder") and `DrillGenerator` (`DRILLS.md`).

## What it does

`LeakAnalysisEngine.analyze(hands: [ParsedHand], ...) -> LeakReport` turns a
set of imported hands into personalized, actionable feedback. Everything it
reports is derived from what `HandHistoryParser` actually captures — no stat
is invented to fill a gap the parser can't back — and push/fold correctness
reuses `PushFoldRange` (`RANGES.md`) rather than introducing a second opinion
on what "correct" looks like.

## `LeakReport` contents

- **`overallTendencies: PreflopTendencies`** — `handsPlayed`, `vpipCount`,
  `pfrCount`, `openLimpCount`, plus `vpipRate`/`pfrRate`/`openLimpRate`
  (`nil`, not `0`, when `handsPlayed == 0` — division-by-zero is modeled as
  "no data" rather than a false 0%).
- **`overallShowdown: ShowdownStats`** — showdown rate and net chips.
- **`positionStats: [PositionStats]`** — the same tendencies/showdown stats,
  broken out per `heroPosition` label, sorted by acting order
  (`positionOrder`).
- **`pushFoldAdherence: PushFoldAdherenceReport`** — see below.
- **`findings: [LeakFinding]`** — up to 3 short, human-readable findings,
  ranked by magnitude (see below).
- **`minHandsForConfidence`** (default 20) and
  **`minPushFoldSpotsForConfidence`** (default 8) — the thresholds used to
  mark a finding `isTentative`.

## VPIP / PFR / open-limp

Computed per hand from hero's preflop actions only
(`hand.actions.filter { $0.street == .preflop && $0.player == hand.heroName }`):

- **VPIP** — hero voluntarily put money in preflop (`call`, `raise`, or `bet`).
- **PFR** — hero raised preflop.
- **Open-limp** — hero's *first* preflop decision was a `call`, **and**
  nobody voluntarily entered before that point (`isUnopenedBeforeHero`, which
  checks that everything before hero's first decision was folds or blind/ante
  posts). This is deliberately narrower than "any limp" — a call after
  someone already opened is a flat-call, not an open-limp.

## Push/fold adherence

`pushFoldAdherence(for:)` only evaluates hands where **all** of these hold:

- `heroPosition` maps to a `Position` the push/fold model has
  (`pushFoldPositionMap` — see the position-collision note below)
- `heroStartingStack` is known and `bigBlind > 0` (so bb-stack is computable)
- effective stack (`heroStartingStack / bigBlind`) is in `[1, 20]`
- `heroHoleCards` is known
- the pot was unopened before hero's first preflop decision
  (`isUnopenedBeforeHero`, same helper as open-limp detection)

For each qualifying hand, `PushFoldRange.decide` gives the *recommended*
action; hero's *actual* action is `.push` if hero's preflop action was an
all-in raise, else `.fold` (a limp or min-raise in a push/fold spot counts as
"not shoving", i.e. `.fold`, for adherence purposes — the model doesn't have
a third option). A mismatch becomes a `PushFoldDeviation`:

- **`.missedShove`** — model says push, hero folded (or limped/min-raised).
- **`.overShove`** — model says fold, hero shoved.

`PushFoldAdherenceReport.adherenceRate = matches / applicableSpots` (`nil` if
`applicableSpots == 0`).

**Position collision:** `pushFoldPositionMap` folds `UTG+1` into `.utg` and
`MP+1` into `.middlePosition` (only present at 8-/9-max tables — see
`HAND-HISTORY.md`) — adherence for those seats is measured against the
nearest coarser bucket the model has, not a distinct one.

## Findings

`buildFindings` considers up to three finding types — `open-limp`,
`missed-shoves`, `over-shoves` — each only included if its count is nonzero,
then sorted by magnitude (percentage) and capped at 3
(`findingsAreCappedAtThree`). Each finding carries `isTentative` independently:
open-limp is tentative when `handsPlayed < minHandsForConfidence` (20);
missed/over-shove findings are tentative when
`applicableSpots < minPushFoldSpotsForConfidence` (8). A tentative finding
still ships — the UI labels it "Tentative" and appends a suffix sentence
rather than hiding it, so a real-but-small-sample signal isn't silently
dropped.

## Small-sample confidence gating, end to end

Confidence gating isn't a single check — it's threaded through three layers,
and all of them use the *same* two constants
(`defaultMinHandsForConfidence = 20`, `defaultMinPushFoldSpotsForConfidence = 8`,
both overridable per call to `analyze`):

1. **`LeakFinding.isTentative`** — per-finding, as above.
2. **`PositionStats`** — the view layer (`LeakAnalysisView.positionRow`) marks
   a position "tentative" when `tendencies.handsPlayed < minHandsForConfidence`.
3. **`DrillFocus.isTentative`** — `DrillGenerator.focus` propagates
   `report.pushFoldAdherence.applicableSpots < report.minPushFoldSpotsForConfidence`
   into the drill screen (`DRILLS.md`).

The intent (per the engine's doc comment): a small-sample finding is real
data, not noise to be suppressed — but it should read as "tentative signal",
not "verdict", until there's enough sample to trust.

## Effective-stack approximation

True effective stack is `min(hero's stack, every opponent's stack still in
the hand)`. A single hand-history line doesn't reliably give that, so
`pushFoldAdherence` approximates it with **hero's own starting stack in bb** —
which is in fact the number that actually determines *hero's* push/fold
decision, even though it isn't the game-theoretic effective stack against a
specific opponent. This is called out explicitly in the engine's doc comment.
