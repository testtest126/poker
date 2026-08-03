# ADR 0001: Android-native and cross-platform framework choice

**Status:** Proposed — not decided. This is a comparison to inform a future
decision, not an implementation plan. No mobile app build starts from this
document; see [ROADMAP.md](../../ROADMAP.md)'s "Platform plan" for the
current sequencing (web first, Android native later, cross-platform
experiments after that).

## Context

Poker Study already has the engine logic (hand evaluation, equity, preflop
range models, ICM, PLO foundation) implemented and ground-truth-tested
**twice**, independently, by deliberate choice:

- **Swift**, in `PokerKit/`, for the iOS app.
- **TypeScript**, in `web/src/engine/`, for the web app — a from-scratch
  port, not SwiftWasm or shared compiled code (see each engine file's header
  comment and `ROADMAP.md`'s platform plan for why: no hidden native
  dependency, runs anywhere a browser does).

Both are pure, self-contained algorithmic logic with zero platform-API
surface — no UIKit/SwiftUI calls, no DOM calls, just functions over plain
data (cards, hands, positions, stacks, payouts). That property matters a lot
for this comparison: it means *any* of the options below could in principle
share that logic across platforms, if the option's language supports it.

The two asks this ADR is scoped to: an **Android-native app**, and
eventually **a cross-platform experiment**. It does not cover whether to
ever consolidate the *existing* iOS app onto a shared framework — that's a
separate, larger decision involving already-shipped, working code, not
addressed here.

## Options considered

### 1. Native Kotlin + Jetpack Compose (Android only)

A third from-scratch engine port, this time in Kotlin, with a fully native
Compose UI. Zero code reuse from the Swift or TypeScript engines — same
"port, don't share" philosophy this project has already applied twice.

- **Reuse:** none. A third engine to write and keep in sync when a range
  model's numbers change (already an accepted cost going from one engine to
  two; this makes it three).
- **Effort:** moderate — Kotlin's type system (data classes, sealed
  classes/enums, extension functions) is close enough to Swift's that most
  of `PokerKit`'s structure translates close to line-for-line. Lowest-risk
  port of the three "write it again" options.
  UI: full native Compose, no cross-platform abstraction to learn.
- **Ceiling:** best possible Android UX/performance, smallest dependency
  footprint, easiest to debug (no bridge, no second runtime).
- **Cost:** Android-only. Doesn't reduce future iOS maintenance burden or
  make a later cross-platform move any easier — it's a dead end for the
  "cross-platform experiment" half of the ask.

### 2. React Native

Reuses **actual code**, not just a familiar language: the TypeScript engine
in `web/src/engine/` has no DOM dependency, so those files (`card.ts`,
`equity.ts`, `pushFoldRange.ts`, `icm.ts`, `trainer.ts`, etc.) are directly
importable into a React Native app essentially unchanged — this is the only
option here offering genuine reuse of code that's *already built and
tested*, not a re-implementation with re-implementation risk. UI components
(`Home.tsx`, `Trainer.tsx`, etc.) would still need rewriting against RN's
primitives (`View`/`Text`/`Pressable` instead of DOM elements + Tailwind),
but the hard, ground-truth-validated math layer transfers as-is.

- **Reuse:** the engine, for real. Zero new engine-port risk.
- **Effort:** UI rewrite only (React knowledge transfers directly); a new
  toolchain (Metro, native modules, Expo-vs-bare-workflow decisions) this
  project doesn't otherwise need.
- **Ceiling:** fine for this app's actual workload — grid taps, small
  Monte Carlo runs, no 60fps-critical animation — so RN's historically
  weaker perf ceiling is a non-issue here. Ecosystem is mature (the New
  Architecture/Fabric era resolved most of RN's old rough edges).
- **Cost:** introduces a full native-bridge build pipeline for what is
  otherwise a simple, math-heavy study tool. Android-and-iOS by default,
  which somewhat blurs the "Android-native app" framing of the first ask —
  it would ship both, whether or not that's wanted yet.

### 3. Flutter

Dart, single codebase, historically the most polished all-in-one
cross-platform toolchain (Android, iOS, and web, all from one codebase).

- **Reuse:** none — a third engine port, this time in Dart, a language with
  no existing footprint in this project (today's two engines are Swift and
  TypeScript; Kotlin is at least adjacent to Swift, Dart is adjacent to
  neither).
- **Effort:** highest of the four — new language, new tooling, no transfer
  from either existing codebase's language investment.
- **Ceiling:** excellent — genuinely the smoothest "write once, ship
  everywhere" experience available today, and the only option that could
  plausibly *also* eventually replace the iOS app (one Flutter codebase
  instead of `PokerKit`+`app` and `web/`) — but that's a much bigger,
  unasked-for scope decision, not implied by tonight's ask.
- **Cost:** a third language with no synergy with the Swift/TypeScript
  skills and code this project already has, for a project that's
  solo-maintained and has explicitly favored lean, low-ceremony choices
  (`CLAUDE.md` §4).

### 4. Compose Multiplatform (Kotlin Multiplatform)

Kotlin, with business logic in a shared `commonMain` module and UI that can
be fully native per platform (Compose for Android; Compose Multiplatform can
also target iOS, though that renderer is newer/less battle-tested than
Flutter's or RN's).

- **Reuse:** none of today's *code*, but the closest re-implementation
  effort to the Swift original of any option here — Kotlin and Swift share
  enough language shape (data classes, sealed types, extension functions)
  that this is likely the easiest and lowest-risk of the "write it a third
  time" options, similar to option 1's estimate.
- **Effort:** for the Android-native ask specifically, this costs
  essentially the same as option 1 — CMP's Android target *is* Jetpack
  Compose. Choosing CMP over plain native Kotlin costs little today and
  keeps a door open.
- **Ceiling:** satisfies **both** asks in this ADR with one framework
  decision instead of two: native Android today via Compose, and a real
  path to the "cross-platform experiment" later via `commonMain` — without
  committing yet to whether that experiment ever includes iOS.
- **Cost:** same "third engine, third language" cost as options 1 and 3.
  CMP's iOS UI story is younger than Flutter's or RN's iOS support, so if
  the cross-platform experiment specifically means "also ship iOS UI from
  the shared codebase," that path is less proven than Flutter's.

## Trade-off summary

| | Code reuse | New language? | Satisfies "Android-native" | Satisfies "cross-platform experiment" | Extra toolchain risk |
|---|---|---|---|---|---|
| Native Kotlin | None | Kotlin (closest to Swift) | Yes, fully | No — dead end | Lowest |
| React Native | **Yes — the actual TS engine** | None (JS/TS) | Yes, but ships iOS too by default | Yes, immediately (already cross-platform) | Bridge/Metro toolchain |
| Flutter | None | Dart (new to this project) | Yes, fully | Yes, most mature | New language + toolchain |
| Compose Multiplatform | None | Kotlin (closest to Swift) | Yes, fully (= native Kotlin cost) | Yes, path open, iOS UI less proven | Moderate |

## Recommendation

**Compose Multiplatform**, held loosely.

It's the one option that answers both halves of the ask — "Android-native"
and "a cross-platform experiment eventually" — with a single framework
decision, at essentially the same near-term cost as writing a plain native
Kotlin app (option 1), since CMP's Android target *is* Jetpack Compose. It
also happens to be the lowest-risk of the three "port the engine a third
time" options, since Kotlin is the closest language to the existing Swift
source of any option that requires a fresh port.

The honest caveat: **React Native is the stronger pick if minimizing
engine-port risk is the top priority**, because it's the only option that
reuses the already-built, already-tested TypeScript engine directly instead
of re-implementing it a third time. That's a real, legitimate trade-off
against CMP's "one decision, two goals" case — not a lesser option, just
optimizing for a different thing (reuse now vs. an Android-native ceiling
plus an open door later).

Flutter is a strong, credible choice if the underlying goal is eventually
one single codebase for every platform including iOS — but that's a bigger
decision than this ADR is scoped to, and isn't implied by tonight's ask.

This is Yakiv's call to make, not one this session is making unilaterally —
no mobile work starts from this document.
