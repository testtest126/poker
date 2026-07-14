# AGENTS.md

<!--
  The single source of truth for how AI agents (and humans) work in this repo.
  Many tools read it — Claude Code, Cursor, GitHub Copilot, Aider, and more; the
  files in .cursor/ and .github/ point them all here so there's one document.
-->

## What this project is
**Poker Study** is a personalized NLHE MTT study app for iOS: import your own
PokerStars hand histories, find your actual leaks, and drill the specific spots
you misplay. The single most important thing to understand before touching it:
it's **off-table only** — study/prep software, never a live table-state reader
or overlay. See `CLAUDE.md` for why that's non-negotiable, and `ai-docs/` for
how each subsystem actually works.

## Build, run, test
- **Setup:** Xcode (full `Xcode.app`, not just Command Line Tools — see below)
  for `PokerKit`; `brew install xcodegen` for the app.
- **Build PokerKit:** `cd PokerKit && swift build`
- **Test PokerKit:** `cd PokerKit && swift test`  &larr; run this before calling any change "done"
  - Requires a full Xcode install (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`,
    or another Xcode you have) — bare Command Line Tools don't ship the `Testing`
    framework the test target imports, and `swift test` fails with `no such
    module 'Testing'`. Details and CI behavior: `ai-docs/TESTING.md`.
- **Build the app:** `cd app && xcodegen generate && open Poker.xcodeproj`, or
  `xcodebuild build -scheme Poker -project Poker.xcodeproj -destination "platform=iOS Simulator,name=<device>"`.
  `app/*.xcodeproj` is generated, not committed (see `app/project.yml`).
- **Run:** open `app/Poker.xcodeproj` in Xcode and run on a simulator.
- **Lint / format:** none configured yet.

> If a change is observable when the project runs, run it and confirm the
> behavior &mdash; not just that tests and types pass.

## Conventions
- **Code:** match the surrounding file. Domain doc comments explain *why*
  (a formula's provenance, a modeling tradeoff, a parser quirk), not what the
  code obviously does — see any file under `PokerKit/Sources/PokerKit` for the
  house style.
- **Architecture:** domain logic lives in `PokerKit` and stays framework-free
  (no SwiftUI, no SwiftData); the app wraps `PokerKit` types in `@Model`
  persistence records and views. New domain logic (range math, parsing, leak
  detection) needs a real test in `PokerKit/Tests`, not just a compile check.
- **Commits:** short, imperative, capitalized (`Add push/fold range model to
  PokerKit`, `Wire up Practice Your Leaks`) — match `git log`. Small, reversible,
  one idea each.
- **Branches / PRs:** solo project — branch for real changes, keep `main`
  buildable at all times (see `CLAUDE.md` §4).
- **Layout:**
  - `PokerKit/Sources/PokerKit/` — domain models & logic (cards, Chen-score
    hand strength, push/fold ranges, hand-history parser, leak analysis, drill
    generation, the 13x13 range grid, bankroll math)
  - `PokerKit/Tests/PokerKitTests/` — tests for the above
  - `app/Sources/` — SwiftUI views + SwiftData record types
  - `app/UITests/` — UI tests, one file per screen
  - `ai-docs/` — per-subsystem docs for agents/devs, start at `ai-docs/README.md`

## The working agreement
These hold for every change, whoever &mdash; or whatever &mdash; makes it:

1. **Verify, don't assume.** "Tests pass" is not "it works." Exercise the real
   change; for a bug fix, first confirm the test *fails without the fix*. See
   `CHECKLIST.md` for the full definition of done.
2. **Silence is never consent.** Before anything irreversible or outward-facing
   &mdash; publish, delete, send, deploy, merge, change access &mdash; get an
   explicit yes. A missing objection is not approval.
3. **Green at your branch is not green at the merge.** Re-verify against the
   current tip of `main` before integrating.
4. **Say what actually happened.** Failed tests are reported with output; skipped
   steps are named; uncertainty is stated as uncertainty.
5. **No secrets or personal data** in the repo, logs, commits, or anything
   shared. Hand histories are personal data — see `CLAUDE.md` §3.
6. **Security-sensitive changes** (auth, tokens, crypto, sessions, access) get a
   review and tests that can actually fail on the bug class. (This app has none
   of those today — no accounts, no network — which is itself a deliberate
   choice; see `CLAUDE.md` §3.)

## Do not
- Don't build anything that only makes sense while a hand is in progress — no
  live table-state reads, no overlay, no real-time assistance. This is the
  project's one non-negotiable rule; see `CLAUDE.md` §1.
- Don't add a server, account system, or any data egress by default — on-device
  only. If a feature genuinely needs one, that's a deliberate decision to
  revisit `CLAUDE.md` for, not a default.
- Don't work around required checks or branch protection.
- Don't automate an irreversible action (arming auto-merge *is* merging).

## Memory (optional)
Durable, non-obvious facts live in `/memory` (read `memory/MEMORY.md` at the
start of a session). Currently empty — add the first fact you'd hate to
re-derive.

## Scaling to many agents (optional)
Solo project — not needed yet. If several agents ever work here at once,
revisit this section before adding coordination ceremony.
