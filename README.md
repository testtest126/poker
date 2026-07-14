# Poker Study

*Working title.*

**A personalized NLHE tournament study & prep helper for iOS.** Not a coach that
gives generic advice — one that learns *your* tendencies, *your* leaks, *your*
common spots, and drills you on those specifically.

<p>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/platform-iOS%2017%2B-lightgrey.svg" alt="iOS 17+">
  <img src="https://img.shields.io/badge/status-early%20scaffold-8a1f1f.svg" alt="early scaffold">
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

## Planned features

- **Personalized preflop ranges** — build and review opening/3-bet/4-bet ranges
  by position and stack depth; compare your actual play against them.
- **ICM / bubble trainer** — push/fold and calling drills weighted by ICM
  pressure near the bubble and at final tables.
- **Bankroll tracker** — buy-ins, cashes, ROI, variance, and simple
  bankroll-management guardrails for MTTs.
- **Hand-history import & leak-finding** — parse PokerStars hand histories,
  surface recurring mistakes (e.g. over-folding to 3-bets, wrong push/fold
  spots), and turn them into targeted drills.
- **Drills** — short, repeatable off-table exercises built from your own leaks
  and hand history, not a generic quiz bank.

## Status

Early scaffold. The app currently shows a placeholder home screen listing the
tools above; none are implemented yet.

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
