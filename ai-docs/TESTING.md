# Testing

## Running `PokerKit`'s tests

```sh
cd PokerKit
swift test
```

`PokerKitTests` uses Swift's `Testing` framework (`import Testing`, `@Test`
functions) rather than `XCTest`. That framework ships **inside a full Xcode
install**, not with the bare Command Line Tools. If `xcode-select -p` points
at `/Library/Developer/CommandLineTools` (or any toolchain that doesn't
bundle Xcode's `Testing` module), `swift test` fails to *compile* with:

```
error: no such module 'Testing'
```

Fix: point `DEVELOPER_DIR` at an actual `Xcode.app` (or any Xcode variant —
a beta build works too) before running:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
# or, if only a beta is installed:
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
```

As of this doc, the suite is 9 test files / 83 `@Test` functions, all
passing:

```
BankrollEntryTests.swift    ChenScoreTests.swift        DrillGeneratorTests.swift
HandHistoryParserTests.swift HoleCardsTests.swift        LeakAnalysisTests.swift
PreflopGridTests.swift      PushFoldRangeTests.swift     StudyToolTests.swift
```

## What CI does (`.github/workflows/ci.yml`)

Two jobs, both on `macos-15` with `DEVELOPER_DIR` forced to the runner's
bundled `Xcode.app` for the same reason as above:

1. **`pokerkit-tests`** — checkout, print toolchain versions, `cd PokerKit &&
   swift test`.
2. **`app-build`** — checkout, `brew install xcodegen`, `xcodegen generate` in
   `app/` (regenerates `Poker.xcodeproj`, which is gitignored), picks
   whichever iPhone simulator is actually available on the runner image
   (`xcrun simctl list devices available` — deliberately not a hardcoded
   device name, since specific iPhone models come and go between runner
   images), then `xcodebuild build -scheme Poker -project Poker.xcodeproj
   -destination "platform=iOS Simulator,name=<device>"`.

Runs on push to `main` and on every PR into `main`.

## Test conventions worth knowing

- Per `CLAUDE.md` §2 ("Verify, don't assume"): new domain logic (range
  parsing, ICM math, leak detection) gets a real test, not just a compile
  check — poker math is easy to get subtly wrong.
- Tests that assert on randomness seed their own generator rather than
  relying on `SystemRandomNumberGenerator` — see e.g.
  `DrillGeneratorTests.sameSeedProducesTheSameSpotSequence` — so results are
  reproducible.
- `app/UITests/` (one file per screen: `PreflopRangeUITests`,
  `PushFoldTrainerUITests`, `BankrollTrackerUITests`,
  `HandHistoryImportUITests`, `DrillsUITests`, `LeakAnalysisUITests`) are
  **not** run by CI today — only `app-build`'s plain `xcodebuild build` runs,
  not `xcodebuild test`. Keep that in mind: a UI test can silently rot until
  someone runs it manually or CI is extended to cover it.
