# Architecture

## The two-package split

- **`PokerKit/`** — a plain Swift package (`swift-tools-version:5.9`, iOS 17 /
  macOS 14). All domain logic lives here: cards, hand strength, push/fold
  ranges, the hand-history parser, leak analysis, drill generation, bankroll
  math. Framework-free by design — no SwiftUI, no SwiftData, no `UIKit`. This
  is what makes it independently testable with plain `swift test` and reusable
  if a second target (widget, watchOS companion, CLI) ever wants the same math.
- **`app/`** — the SwiftUI iPhone app. Depends on `PokerKit` as a local Swift
  package (`app/project.yml` → `packages.PokerKit.path: ../PokerKit`). Built via
  [XcodeGen](https://github.com/yonaskolb/XcodeGen): `app/Poker.xcodeproj` is
  generated from `app/project.yml`, not committed (`.gitignore`).

Rule of thumb: if the answer to "is this poker math or a domain rule" is yes,
it belongs in `PokerKit`. If it's persistence, navigation, or SwiftUI layout,
it belongs in `app/`.

## Where things live

```
PokerKit/Sources/PokerKit/
  Card.swift              Rank, Suit, Card
  HoleCards.swift         two-card hand: notation, canonical init, random()
  Position.swift          6 preflop positions for an unopened pot (BB excluded)
  ChenScore.swift         Chen formula: ranks the 169 starting hands
  PushFoldRange.swift     position × stack → shove %, PushFoldDecision
  PushFoldSpot.swift      one drillable spot (hand + position + stack)
  PreflopGrid.swift       13×13 grid enumeration/notation, reuses PushFoldRange
  HandHistory.swift       ParsedHand, HandAction, TournamentSession, HandHistoryFile
  HandHistoryParser.swift PokerStars .txt → ParsedHand (defensive, never throws)
  LeakAnalysis.swift      LeakAnalysisEngine: VPIP/PFR/limp, push/fold adherence
  DrillGenerator.swift    LeakReport → DrillFocus → weighted PushFoldSpot stream
  BankrollEntry.swift     session log entry + ROI/win-rate/running-bankroll math
  StudyTool.swift         the 5 top-level screens (enum driving ContentView's list)

app/Sources/
  PokerApp.swift              @main, SwiftData ModelContainer for the 2 record types
  ContentView.swift           NavigationStack + List(StudyTool.allCases)
  PreflopRangeView.swift      13×13 grid viewer (PreflopGrid)
  PushFoldTrainerView.swift   plain random push/fold drill
  DrillsView.swift            "Practice Your Leaks" — personalized drill (DrillGenerator)
  HandHistoryImportView.swift .txt file import → HandRecord rows
  LeakAnalysisView.swift      renders LeakReport (Leak Finder screen)
  BankrollTrackerView.swift + BankrollEntryFormView.swift
  HandRecord.swift             @Model wrapping ParsedHand
  BankrollEntryRecord.swift    @Model wrapping BankrollEntry
```

`ai-docs/RANGES.md`, `HAND-HISTORY.md`, `LEAK-ANALYSIS.md`, `DRILLS.md`, and
`PREFLOP-GRID.md` each go deeper on one of the subsystems above.

## Data flow: import → analyze → drill

This is the app's core loop, and the reason `PokerKit`'s pieces are shaped the
way they are — each stage's output is exactly the next stage's input:

```
 .txt file            HandHistoryParser.parse(text)
      │                        │
      ▼                        ▼
 HandHistoryImportView ──▶ HandHistoryFile { hands: [ParsedHand], skipped: [...] }
      │  (dedupes by handId, inserts into SwiftData)
      ▼
 HandRecord (SwiftData, stores rawText verbatim)
      │
      │  LeakAnalysisView / DrillsView re-parse rawText on demand:
      │  HandHistoryParser.parse(record.rawText).hands.first
      ▼
 [ParsedHand]  ──▶  LeakAnalysisEngine.analyze(hands:)  ──▶  LeakReport
      │                                                        │
      │                                                        ▼
      │                                          DrillGenerator.focus(from:) ──▶ DrillFocus?
      │                                                                              │
      ▼                                                                              ▼
 LeakAnalysisView renders findings/adherence          DrillsView: DrillGenerator.spot(focus:)
                                                        deals a weighted PushFoldSpot,
                                                        graded against PushFoldRange
```

Notable: `HandRecord` stores `rawText` and re-parses it on every read rather
than persisting `ParsedHand`'s fields redundantly (see `HAND-HISTORY.md` /
`LEAK-ANALYSIS.md`). This keeps the parser as the single source of truth for
what a hand means, at the cost of re-parsing on every screen load — fine at
personal-hand-history scale, worth revisiting if that ever becomes slow.

## Persistence (SwiftData)

Two `@Model` types, both declared in `PokerApp.swift`'s `.modelContainer`:

- **`HandRecord`** — wraps an imported `ParsedHand`. `handId` is
  `@Attribute(.unique)` so re-importing an overlapping file is a no-op for
  hands already stored (`HandHistoryImportView.importFile` also checks
  `existingIds` before inserting, so duplicates are skipped explicitly, not
  just deduped by the unique constraint).
- **`BankrollEntryRecord`** — wraps a `BankrollEntry` (buy-in/cash/notes per
  session). Has `asEntry` / `apply(_:)` to convert to and update from the
  plain `PokerKit` struct.

Both records exist *only* in `app/` — `PokerKit` never imports `SwiftData`.
Everything is on-device; there is no server and no account (see the project's
`CLAUDE.md` §3, "Privacy-first"). Hand-history files never leave the phone —
`HandHistoryImportView` reads the file directly via `fileImporter` and parses
in-process.

## Status vs. the README

The top-level `README.md` currently describes the app as an "early scaffold"
with none of the planned features implemented. That's stale: as of this doc,
Preflop Ranges, the Push/Fold Trainer, Bankroll Tracker, Hand History
Import, the Leak Finder, and "Practice Your Leaks" are all implemented,
tested, and wired into `ContentView`. Trust the code and `ai-docs/` over the
README's "Status" section until it's updated.
