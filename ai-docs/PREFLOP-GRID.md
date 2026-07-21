# Preflop Range Grid

Source: `PokerKit/Sources/PokerKit/PreflopGrid.swift`. Tests:
`PreflopGridTests.swift`. Consumed by `app/Sources/PreflopRangeView.swift`
("Preflop Ranges" screen).

## What it does

Enumerates the classic 13×13 starting-hand grid and lays out push/fold,
opening, and defending decisions across it. It is purely an
enumeration/layout helper — it introduces no new range model, reusing
`PushFoldRange.decide`, `OpeningRange.decide`, `CallingRange.decideVsShove`,
and `CallingRange.decideVsOpen` (all ultimately backed by `ChenScore` — see
`RANGES.md`) for every cell's actual decision.

## Layout convention

Both axes run **A down to 2** (`ranks = Rank.allCases.sorted(by: >)`).
Standard poker-grid convention:

- **Diagonal** (`row == col`) — pairs (`"AA"`, `"KK"`, ... `"22"`)
- **Above the diagonal** (`row < col`) — suited (`"AKs"`)
- **Below the diagonal** (`row > col`) — offsuit (`"AKo"`)

`notation(row:col:)` derives the canonical string for any cell; `hands` is
the precomputed 13×13 `[[HoleCards]]` built by calling
`HoleCards(canonical:)` on every cell's notation (all 169 canonical starting
hands, each represented once).

## `decisions(position:effectiveStackBB:) -> [[PushFoldDecision]]`

Maps `PushFoldRange.decide(hand:position:effectiveStackBB:)` over every cell
of `hands`, indexed `[row][col]` to match.

## `openingDecisions(position:effectiveStackBB:) -> [[OpeningDecision]]`

Same shape, mapping `OpeningRange.decide(hand:position:effectiveStackBB:)`
instead.

## `callingDecisions(caller:shover:effectiveStackBB:) -> [[CallVsShoveDecision]]?`

Maps `CallingRange.decideVsShove(hand:caller:shover:effectiveStackBB:)` over
every cell — hero (`caller`, a `DefendingPosition`) is facing an all-in shove
from `shover`. Returns `nil` — not a grid of nonsense — when `caller`
couldn't actually be facing that shove (see `RANGES.md`'s "Positions
modeled").

## `openDefenseDecisions(defender:opener:effectiveStackBB:) -> [[OpenDefenseDecision]]?`

Same shape, mapping `CallingRange.decideVsOpen(hand:defender:opener:effectiveStackBB:)`
— hero (`defender`) is facing an open-raise from `opener`. Also returns `nil`
for an invalid position pairing.

`PreflopRangeView` has a mode control (Push/Fold, Opening, Facing a Shove,
Facing an Open) that picks which of these four functions backs the grid,
plus position picker(s) and a stack slider (1–20bb for the two short-stack
modes, 20–100bb for the two standard-stack modes) driving the shared
parameters live. The two aggressor modes render one `Color.accentColor`
(shove/raise) or `Color(.secondarySystemBackground)` (fold) cell per
decision. The two defending modes add a third color for 3-bet/call so all
three actions are visually distinct — the view only cares about which of
`push`/`raise`/`threeBet`/`call`/`fold` a cell's action is, never the
decision types themselves.

`gridDecisionsMatchDirectPushFoldRangeDecisions`,
`gridOpeningDecisionsMatchDirectOpeningRangeDecisions`,
`gridCallingDecisionsMatchDirectCallingRangeDecisions`, and
`gridOpenDefenseDecisionsMatchDirectCallingRangeDecisions` (tests) are the
load-bearing guarantee here: every grid cell's decision is required to
exactly match calling the corresponding model directly for that same
hand/position(s)/stack — the grid is not allowed to drift into its own logic
for any of the four models. `gridReturnsNilForInvalidPositionPairings`
covers the two defending modes' `nil` case specifically.
