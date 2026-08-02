# Poker Study

**A free, open-source Texas hold'em study tool.** Preflop ranges, equity,
and ICM math you can see and check — not a paywalled black box. See
[ROADMAP.md](ROADMAP.md) for the full vision, including the honest line on
what this is *not* (a postflop GTO solver — not yet, and not implied).

<p>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/web-free%2C%20no%20account-2ea44f.svg" alt="free, no account">
  <img src="https://img.shields.io/badge/platform-iOS%2017%2B-lightgrey.svg" alt="iOS 17+">
</p>

## Off-table only — this is not a real-time assistant

**This tool is for study, review, and preparation away from the table.** It
does not read table state, does not run during a hand, and is not an
overlay or real-time decision aid. Using real-time assistance (RTA) while
playing violates most sites' Terms of Service — that's explicitly out of
scope for this project, by design, not just by omission.

## What's here

Two platforms, sharing the same *validated* logic (ported, not copy-pasted
— each platform's engine has its own test suite checked against the same
ground-truth numbers):

- **`web/`** — a free, client-side web app. No install, no account, no
  paywall, nothing you enter leaves your device. Preflop range explorer and
  equity calculator, more on the way.
- **`app/` + `PokerKit/`** — the original iOS app: everything in `web/`
  plus hand-history import, personalized leak detection, spaced drills, a
  bankroll tracker, ICM, PKO bounty math, and an early Omaha/PLO
  foundation.

Every tool is backed by tests and documented per-subsystem in
**[ai-docs/](ai-docs/README.md)** — what's sourced from a citation, what's
a disclosed hand-tuned judgment call, and why.

## Status

Actively developed on both platforms. iOS has the deeper feature set today
(built first); the web app is newer and focused on the core preflop/equity
loop. See **[ROADMAP.md](ROADMAP.md)** for what's shipped, what's next, and
the platform plan (web → Android native → cross-platform, decided later).

## Tech

- **Web**: TypeScript, fully client-side, no server, no account.
- **iOS**: Swift / SwiftUI, on-device. No server, no account, no data
  leaving the phone.

Both keep the same privacy posture for the same reason: hand histories,
stats, and study data are personal, and this project doesn't need a server
to be useful.

## Architecture

- **`PokerKit/`** — the shared Swift package for the iOS app: domain models
  for every study tool. Buildable and tested from commit one.
- **`app/`** — the SwiftUI iPhone app. Built in Xcode via `app/project.yml`
  (XcodeGen); depends on `PokerKit`.
- **`web/`** — the web app: a TypeScript engine port (`web/src/engine/`)
  plus a React UI, built with Vite. See `web/README.md` for local dev.

See **[ai-docs/](ai-docs/README.md)** for a per-subsystem breakdown and
**[AGENTS.md](AGENTS.md)** for build/test/run commands on both platforms.
