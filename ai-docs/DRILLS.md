# Drills — "Practice Your Leaks"

Source: `PokerKit/Sources/PokerKit/DrillGenerator.swift`. Tests:
`DrillGeneratorTests.swift`. Consumed by `app/Sources/DrillsView.swift`.

## What it does

Closes the loop **import → leak finding → targeted practice**. Given a
`LeakReport` (`LEAK-ANALYSIS.md`), `DrillGenerator` finds the single
position + stack region where the user's push/fold play deviates most, then
deals `PushFoldSpot`s (`RANGES.md`) weighted toward that region — without
inventing a second notion of "correct": grading still goes through
`PushFoldRange`, same as every other screen.

## `DrillGenerator.focus(from: LeakReport) -> DrillFocus?`

1. Take `report.pushFoldAdherence.deviations`. If empty, return `nil` — either
   there isn't enough imported data yet (no applicable push/fold spots) or the
   user's play in those spots was clean. `DrillsView` treats `nil` as "show
   general (fully random) practice" and explains why in the UI.
2. Group deviations by `position`. Pick the position with the most
   deviations. Ties break deterministically toward the *later* position in
   `Position.allCases` order (`UTG < MP < HJ < CO < BTN < SB`) — not
   dictionary iteration order, which Swift doesn't guarantee is stable across
   runs (`tiedDeviationCountsBreakTowardTheLaterPosition`).
3. `stackRange` is `[min, max]` effective stack (bb) across that position's
   deviations, floored/ceilinged to `Int`.
4. `dominantKind` is whichever deviation type — `.missedShove` or
   `.overShove` — is at least half of the group's deviations; used only for
   the human-readable explanation, not to filter which spots get dealt.
5. `isTentative` propagates straight from
   `report.pushFoldAdherence.applicableSpots < report.minPushFoldSpotsForConfidence`
   (the same threshold described in `LEAK-ANALYSIS.md`).

`DrillFocus.explanation` renders the personalization legibly for the drill
screen, e.g. *"Focused on: missed shoves, 5–9bb, CO — your weakest area from
your last import."* — deliberately not a black box.

## `DrillGenerator.spot(focus:focusWeight:) -> PushFoldSpot`

With probability `focusWeight` (default `defaultFocusWeight = 0.7`, and only
when `focus != nil`), position and stack are drawn from the focus region and
the hole cards are still random; otherwise it falls back to
`PushFoldSpot.random()` — a fully random spot, identical to the plain
Push/Fold Trainer. The weight is intentionally `< 1.0` so a focused session
still surfaces some variety instead of only ever drilling the one leaked
region (`spotAlwaysMatchesFocusRegionWhenFocusWeightIsOne` /
`spotNeverUsesTheFocusRegionWhenFocusWeightIsZero` /
`focusWeightApproximatesTheRequestedProportion` cover the boundary and
statistical behavior).

## How `DrillsView` wires it together

`DrillsView.computeFocusIfNeeded()` (called once, on `.onAppear`):

```swift
let parsedHands = records.compactMap { HandHistoryParser.parse($0.rawText).hands.first }
hasImportedHands = !parsedHands.isEmpty
if hasImportedHands {
    focus = DrillGenerator.focus(from: LeakAnalysisEngine.analyze(hands: parsedHands))
}
spot = DrillGenerator.spot(focus: focus)
```

Note it re-parses every `HandRecord.rawText` on screen appearance rather than
reading persisted `ParsedHand` fields — the same pattern `LeakAnalysisView`
uses (see `ARCHITECTURE.md`'s data-flow diagram). `nextHand()` calls
`DrillGenerator.spot(focus:)` again with the same cached `focus`, so the
weighting stays stable for the rest of the session; `focus` is only
recomputed on next screen appearance (e.g. after a fresh import).

The screen shows one of three header states, driven by `focus` and
`hasImportedHands`: no hands imported yet → prompt to import; hands imported
but no deviations found → "showing general practice"; a focus exists →
`DrillFocus.explanation`.
