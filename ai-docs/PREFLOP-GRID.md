# Preflop Range Grid

Source: `PokerKit/Sources/PokerKit/PreflopGrid.swift`. Tests:
`PreflopGridTests.swift`. Consumed by `app/Sources/PreflopRangeView.swift`
("Preflop Ranges" screen).

## What it does

Enumerates the classic 13×13 starting-hand grid and lays out push/fold
decisions across it. It is purely an enumeration/layout helper — it
introduces no new range model, reusing `PushFoldRange.decide` and
`ChenScore` (`RANGES.md`) for every cell's actual decision.

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
of `hands`, indexed `[row][col]` to match. This is the only function the app
calls — `PreflopRangeView` renders one `Color.accentColor` (shove) or
`Color(.secondarySystemBackground)` (fold) cell per decision, with a position
picker and a stack slider (1–20bb) driving the two parameters live.

`gridDecisionsMatchDirectPushFoldRangeDecisions` (test) is the load-bearing
guarantee here: every grid cell's decision is required to exactly match
calling `PushFoldRange.decide` directly for that same hand/position/stack —
the grid is not allowed to drift into its own logic.
