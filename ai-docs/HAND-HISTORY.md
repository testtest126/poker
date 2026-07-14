# Hand History Import & Parsing

Source: `PokerKit/Sources/PokerKit/HandHistory.swift`, `HandHistoryParser.swift`.
Tests: `HandHistoryParserTests.swift`. Consumed by `app/Sources/HandHistoryImportView.swift`
(via `HandRecord`).

## Format

Parses **PokerStars tournament hand-history exports** — the standard
`PokerStars Hand #... Tournament #...` `.txt` format. Nothing else is
supported (no other site's format, no cash-game-specific quirks beyond what
overlaps with tournament hands).

Per `CLAUDE.md` §1, this only ever operates on histories from hands that have
**already finished** — it's a file parser, not a live reader. There is no
code path anywhere that reads table state while a hand is in progress.

## How the hero is identified

The parser doesn't take a username parameter. It identifies the hero as
**whichever player the file deals hole cards to** — the `Dealt to <name>
[Xx Yy]` line — because PokerStars only ever shows hole cards for the account
the history was exported for. This is what lets import work with zero setup.

## Parsing strategy: defensive, never throws

`HandHistoryParser.parse(_ text: String) -> HandHistoryFile` never throws.
The file is split into per-hand blocks (`splitIntoHandBlocks`, splitting on
`PokerStars Hand #` / `PokerStars Game #` lines), and each block is parsed
independently. A hand that doesn't match the expected shape — missing header,
no seats, no button, no `Dealt to` line, unparseable hole cards — is recorded
in `HandHistoryFile.skipped` with a human-readable `reason`, and parsing
continues with the rest of the file. One malformed hand never fails the whole
import (`HandHistoryParserTests.malformedHandDoesNotPreventOthersFromParsing`).

`HandHistoryFile` also exposes `.sessions: [TournamentSession]` — hands
grouped by `tournamentId`, ordered by each session's earliest hand (hands with
no tournament id group under `nil`, sorted last).

## What's parsed per hand (`ParsedHand`)

- `handId`, `tournamentId`, `date` (naive — see Known limitations)
- Blinds/ante: `smallBlind`, `bigBlind`, `ante`
- Hero: `heroName`, `heroSeat`, `heroPosition` (see below), `heroHoleCards`,
  `heroStartingStack`
- `actions: [HandAction]` — one entry per street per action, `kind` ∈
  `{postAnte, postSmallBlind, postBigBlind, fold, check, call, bet, raise}`.
  For a `raise`, `amount` is the **new total bet for that street**, not the
  increment — `HandHistoryParser.computeHeroNet` tracks each player's
  running per-street commitment to work out actual increments.
- `board: [Card]` — accumulates through flop/turn/river
- `heroNetChips` — total returned/collected minus total invested, computed
  from actions plus `"Uncalled bet ... returned to"` / `"... collected ..."`
  summary lines
- `heroBountyWon` — KO/PKO bounty collected this hand, if any (`nil` if the
  hand had none, not `0`)
- `wentToShowdown` — true only if `*** SHOW DOWN ***` appears; a hand can
  reach the river and still end without a showdown if the last bet takes the
  pot uncontested
- `rawText` — the original block, kept verbatim (this is what `HandRecord`
  persists and what every downstream screen re-parses from — see
  `ARCHITECTURE.md`)

`ParsedHand.heroSawFlop` checks "did hero fold preflop", not "did hero act on
the flop" — when the remaining players are all-in preflop, PokerStars deals
the rest of the board straight through with no further action lines at all,
so checking for a flop-street action would miss those hands.

## Position labeling

`heroPosition` is derived from seat count and distance from the button
(`positionLabelsByCount`, keyed by table size 2–9), not printed literally
anywhere in the file. Seats are rotated to start at the button, then indexed
into the label list for that table size.

**Known limitation: position naming above 6-handed collides.** The label sets
for 7/8/9-handed tables include `MP`/`MP+1` and `UTG+1`, which are folded
into the *same* `PushFoldRange`/`LeakAnalysisEngine` buckets as `MP` and `UTG`
respectively (see `LeakAnalysisEngine.pushFoldPositionMap` in
`LEAK-ANALYSIS.md`) — so push/fold adherence for those seats is measured
against the nearest coarser position the model actually has, not a distinct
one. `positionLabel` also returns `nil` outright for tables outside 2–9
seated players.

**Known limitation: naive timestamps.** The header's
`yyyy/MM/dd HH:mm:ss` timestamp is parsed with a fixed `UTC` `TimeZone` and
`en_US_POSIX` locale (`parseHeader`) — this is whatever timezone PokerStars
stamped the file with, not necessarily true UTC, and no timezone conversion
or DST handling is attempted. Treat `ParsedHand.date` as an ordering key
within one import, not an authoritative wall-clock time.

## Errors and edge cases handled

- Regex-based extraction throughout (`captures(_:in:)`), each call independently
  optional — a missing capture group degrades gracefully rather than crashing.
- Amounts with thousands separators (`"1,234"`) are stripped before `Decimal`
  parsing (`decimal(from:)`).
- `computeHeroBounty` returns `nil` (not `0`) when no bounty line is found, so
  callers can distinguish "no KO this hand" from "$0 bounty".
