# Poker Study

*Working title.*

**A personalized NLHE tournament study & prep helper for iOS.** Not a coach that
gives generic advice — one that learns *your* tendencies, *your* leaks, *your*
common spots, and drills you on those specifically.

<p>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/platform-iOS%2017%2B-lightgrey.svg" alt="iOS 17+">
  <img src="https://img.shields.io/badge/status-core%20toolset%20shipped-2ea44f.svg" alt="core toolset shipped">
</p>

## Off-table only — this is not a real-time assistant

**This tool is for study, review, and preparation away from the table.** It does
not read the table state, does not run during a hand, and is not an overlay or
real-time decision aid. Using any kind of real-time assistance (RTA) while
playing violates PokerStars' Terms of Service — that is explicitly out of scope
for this project, by design, not just by omission. Every feature here operates
on hand histories you've already played, or on drills you run before/after a
session — never live.

## What it's for

The user is an NLHE MTT grinder on PokerStars.se. The idea: import your hand
histories, find your actual leaks (not generic ones), and drill the specific
spots you get wrong — preflop ranges, ICM/bubble decisions, push/fold — with a
bankroll tracker to keep the whole thing honest.

## What's built

Five tools, wired up and live in the app today:

- **Preflop Ranges** — a 13×13 grid viewer with two modes: push/fold shove
  ranges for short stacks (~1–20bb), and opening (raise-first-in) ranges for
  standard stacks (~20–100bb), by position and effective stack. Both are
  hand-tuned study aids, not solver output — see `ai-docs/RANGES.md` for the
  source basis. Still no 3-bet/4-bet ranges — see Roadmap.
- **Push/Fold Trainer** — shove-or-fold drills for short stacks (~1–20bb), by
  position and effective stack.
- **Hand History Import & Leaks** — parse PokerStars hand-history exports and
  surface a leak report (VPIP/PFR/limp tendencies, push/fold adherence,
  ranked findings).
- **Practice Your Leaks** — push/fold drills weighted toward the exact spots
  your imported hands show you misplay.
- **Bankroll Tracker** — buy-ins, cashes, ROI, and win-rate across logged
  sessions.

All of the above are backed by a tested `PokerKit` domain layer (94 passing
tests) and a green CI pipeline (`.github/workflows/ci.yml`) that runs the
`PokerKit` test suite and builds the iOS app on every push and PR. See
**[ROADMAP.md](ROADMAP.md)** for what's next (ICM/bankroll depth, a
spaced-repetition drill engine, and polish on the above) and
**[ai-docs/](ai-docs/README.md)** for how each tool actually works under the
hood.

## Status

Core toolset shipped and in active development — not a finished product, but
past the scaffold stage: every tool listed above is implemented, tested, and
reachable from the app's home screen.

## Tech

Swift / SwiftUI, on-device. No server, no account, no data leaving the phone —
hand histories and stats are personal and stay local.

## Architecture

- **`PokerKit/`** — the shared Swift package: domain models for the study
  tools. Buildable and tested from commit one.
- **`app/`** — the SwiftUI iPhone app. Built in Xcode via `app/project.yml`
  (XcodeGen); depends on `PokerKit`.

See **[ai-docs/](ai-docs/README.md)** for a per-subsystem breakdown (ranges,
hand-history parsing, leak analysis, drills) and **[AGENTS.md](AGENTS.md)**
for build/test/run commands — both written to get an agent or a returning
dev oriented fast.
