# Roadmap

## The vision

A **free, open-source, easy-to-use Texas hold'em study tool** — the kind of
thing you'd point a friend to instead of a paywalled subscription. Think
"GTO Wizard, but completely free": preflop ranges, equity, and ICM math you
can actually see and check, not a black box behind a paywall.

**Free and open means free and open — no paywall, no account required, no
data leaving your device for anything this tool computes.** The code is MIT
licensed (see [LICENSE](LICENSE)); anyone can read it, run it, fork it, or
send a PR.

## What this is NOT (yet): a postflop GTO solver

This is the single most important line in this document, so it's not buried:
**this project does not compute real-time postflop GTO solutions, and
nothing on this site or in this app should be read as claiming that.**
A genuine postflop solver (CFR-based, handling arbitrary bet sizes and full
ranges on every street) is a serious, separate computational undertaking —
real ones are the product of years of dedicated engineering. It is a
plausible *future* milestone for this project, not something shipped today,
and if/when it exists here it will say so explicitly, not be implied by a
polished UI.

What this project *does* ship today is real, and it's genuinely useful on
its own:

- **Preflop ranges** grounded in published charts and standard MTT theory
  (opening/RFI, push/fold, facing a shove, facing an open, 3-bet/4-bet) —
  every hand-tuned number disclosed as exactly that, every sourced number
  cited. See `ai-docs/RANGES.md`.
- **An equity calculator** — exact enumeration where tractable, fixed-seed
  Monte Carlo otherwise, validated against published ground-truth equities
  (e.g. AA vs. KK ≈ 82.4%). See `ai-docs/EQUITY.md`.
- **ICM** (the Malmuth-Harville model) — exact tournament-equity math,
  validated against a published worked example, plus an ICM-adjusted
  calling-equity overlay. See `ai-docs/ICM.md`.
- **PKO bounty math**, **game-format defaults**, and an early **Omaha/PLO**
  foundation (hand evaluation + equity, no preflop ranges yet).

Call this what it accurately is: a **GTO-informed preflop/equity/ICM
trainer** — a strong, honest study tool built entirely on cited sources and
exact math, not a solver, and not pretending to be one.

## Platform plan

**Web first.** A free tool only reaches people if they can open it without
installing anything — a browser tab beats an App Store listing for that.
The web app (`web/`) is a from-scratch TypeScript port of the same engine
logic already validated in `PokerKit` (Swift) — same algorithms, same
sourced numbers, same ground-truth tests, re-implemented rather than
compiled cross-platform, so the web app has no hidden native dependency and
runs anywhere a browser does. Fully client-side: nothing you enter is sent
anywhere.

1. **Web study tool** *(in progress)* — preflop range explorer, equity
   calculator, and ICM calculator as a clean, mobile-friendly, zero-paywall
   web app. This is tonight's focus.
2. **Android, native** *(future)* — once the web tool is solid, a native
   Android app is the next reach — Android has the larger global poker-app
   audience share among free/non-iOS users this project wants to reach.
3. **Cross-platform experiments** *(future, later)* — once there are two
   independently-maintained platforms (iOS via `app/`+`PokerKit`, web via
   `web/`), it'll be worth revisiting whether a shared engine layer (e.g.
   Kotlin Multiplatform, or compiling the TypeScript engine down for native
   use) is worth the complexity, versus keeping three independent,
   individually-simple codebases. Not decided yet — a real decision for
   that future date, not today. See
   [docs/adr/0001-mobile-platform-choice.md](docs/adr/0001-mobile-platform-choice.md)
   for an honest comparison of Compose Multiplatform vs. React Native vs.
   Flutter vs. native Kotlin for this project specifically — a reference
   for that future decision, not a decision made now.

The existing **iOS app** (`app/` + `PokerKit/`) keeps developing in
parallel — it isn't being deprecated by the web effort. The two share no
code today (Swift vs. TypeScript); see "Cross-platform experiments" above
for whether that's worth changing later.

## What's built today

**iOS** (`PokerKit/` + `app/`) — Preflop ranges (push/fold, opening,
facing-shove, facing-open, 3-bet/4-bet), an equity calculator (exact +
Monte Carlo), ICM + ICM risk premium, PKO bounty math, game-format
defaults, and an early Omaha/PLO foundation. All tested (`swift test`,
green from commit one) and documented per-subsystem in `ai-docs/`.

**Web** (`web/`) — *(new tonight, see the PRs that landed this session for
exactly what's live)* — a TypeScript port of the core engine (hand
evaluation, equity, preflop ranges), starting with a preflop range explorer
and an equity calculator.

## Process

Small, tested, honestly-scoped increments — the working agreement in
[CLAUDE.md](CLAUDE.md) and [AGENTS.md](AGENTS.md) applies here exactly as it
does everywhere else in this repo: every judgment-based number gets
disclosed as a judgment call, every sourced number gets a citation, and
nothing ships claiming to be more than it is.
