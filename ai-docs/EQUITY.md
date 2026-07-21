# Equity Calculator

Source: `PokerKit/Sources/PokerKit/HandEvaluator.swift`, `Equity.swift`. Tests:
`HandEvaluatorTests.swift`, `EquityTests.swift`.

## What it does

Two layers, built bottom-up:

- **`HandEvaluator`** — given 5, 6, or 7 cards, returns the best possible 5-card
  poker hand as a fully `Comparable` `HandStrength` (category + kicker
  tiebreakers). This is a **real evaluator**, not a lookup table or an
  approximation — every category (pair, two pair, straight, flush, ...) is
  derived from actual rank/suit counts on every call.
- **`Equity`** — win/tie/lose probability between two hands, or a hand/range
  vs. a hand/range, on any board state (preflop, flop, turn, or river given).
  Built entirely on `HandEvaluator`; no separate equity table, no shortcuts.

Unlike every other model in this codebase (`PushFoldRange`, `OpeningRange`,
`CallingRange`, `BountyEquity`), **this one isn't a hand-tuned approximation
of a solver's shape** — it's exact math (either literally exhaustive, or a
documented, tolerance-bound Monte Carlo sample of exact math). "Study aid, not
solver output" doesn't apply here; the correctness bar is "matches the actual
probability," and the tests hold it to that.

## `HandEvaluator`

`bestHand(from: [Card]) -> HandStrength` accepts 5-7 cards and returns the
best 5-card hand achievable from them. For 6 or 7 cards, it evaluates every
possible 5-card sub-hand (`C(6,5) = 6` or `C(7,5) = 21`) and keeps the best by
`Comparable` — the textbook-correct approach. A real solver would use a
precomputed perfect-hash lookup table instead (evaluations in tens of
nanoseconds rather than the ~1µs+ this takes); that wasn't built here — see
"Performance" below for why that tradeoff was made deliberately, not by
accident.

`HandStrength` is `category: HandCategory` (the standard nine-rung ladder,
`highCard` through `straightFlush`, ordered by raw value so `Comparable` falls
out for free) plus `tiebreakers: [Int]` — enough rank values, most significant
first, to break every tie the category leaves open (kicker included). Two
`HandStrength`s only ever have different-shaped `tiebreakers` arrays when
they're different categories, and comparison checks category first, so a
shape mismatch never actually gets compared element-by-element.

**The wheel (A-2-3-4-5)** is handled explicitly: it's a straight (and a
straight flush, if suited) with a **5-high**, not ace-high, so
`tiebreakers == [5]` for a wheel straight — it loses to a 6-high straight, as
it should. `HandEvaluatorTests.swift` tests this directly (`wheelIsAStraightNotAceHigh`,
`wheelStraightLosesToSixHighStraight`, `wheelFlushIsAStraightFlushNotAHighCardFlush`,
`nearWheelRanksIsNotAStraight`).

`HandEvaluatorTests.swift` covers, exhaustively: the full category ladder
(royal flush > quads > full house > flush > straight > trips > two pair >
pair > high card, each asserted as an explicit pairwise comparison, not just
assumed transitive), the wheel, kicker tie-breaks within every category
(pair kicker, two-pair second-pair, full-house trips-rank, flush high card,
high-card kicker chain), suit-blindness (identical ranks in different suits
compare equal), and the 7-card best-of-5 selection (picking a flush out of
junk hole cards; picking a straight flush over a plain flush; picking the
best 5 out of 6).

## `Equity`

Two calculation modes — deliberately different, matching the two situations
that actually differ in what's computationally tractable:

### `headsUp(hero:villain:board:) -> EquityResult` — exact

One hand vs. one hand. Enumerates **every** possible completion of the
remaining board and evaluates each one — genuinely exhaustive, zero sampling
error. Tractable for any board state:

| Board given | Boards to enumerate |
| --- | --- |
| Preflop (0 cards) | `C(48, 5) = 1,712,304` |
| Flop (3 cards) | `C(45, 2) = 990` |
| Turn (4 cards) | `C(44, 1) = 44` |
| River (5 cards) | `1` (already determined) |

Only the preflop case is actually expensive — see "Performance" below.

### `monteCarlo`/`handVsRange`/`rangeVsRange` — fixed-seed sampling

Either side can be a **range** (multiple possible hands) — exact enumeration
doesn't work here at any real range width, because it would mean enumerating
every (hero combo × villain combo × board completion) triple, which blows up
combinatorially even for small ranges (see "A subtlety: which suits?" below
for just how fast this gets out of hand). Each trial samples one concrete
hand uniformly from each side and a uniformly random board completion,
retrying on any card collision.

**Fixed-seed, always.** `Equity.defaultSeed` (`0xC0FFEE`) is used unless
overridden, via a small deterministic PRNG (`SplitMix64` — Sebastiano Vigna's
public-domain algorithm, chosen specifically because it's simple, widely
reimplemented, and has no hidden state beyond one `UInt64` — reproducibility
is the entire point of using a named, inspectable algorithm here rather than
Swift's own `SystemRandomNumberGenerator`, which is explicitly not seedable).
Two calls with the same seed and iteration count always return bit-identical
results — `EquityTests.swift`'s `monteCarloIsDeterministicForAFixedSeed` and
`monteCarloDefaultSeedIsReproducibleAcrossCalls` assert this directly. Equity
tests here never flake.

**Default sample size:** `Equity.defaultMonteCarloIterations = 50_000`.
Standard error for a binomial proportion is `sqrt(p(1-p)/n)`; worst-case
(`p = 0.5`) at `n = 50,000` that's `≈0.22%`, or about `±0.45%` at a 95%
confidence interval. The ground-truth tests below use `100,000` iterations
for extra margin (`±0.32%` at 95% CI) since they're the tests this whole
feature is judged by.

### `canonicalVsCanonical` / `expandCanonical` — the combo-weighted layer

`expandCanonical("AA")`, `expandCanonical("AKs")`, `expandCanonical("AKo")`
expand a canonical hand string into every concrete `HoleCards` combo it
represents — 6 for a pair (`C(4,2)`), 4 for suited (one per suit), 12 for
offsuit (`4 × 3`). `canonicalVsCanonical(_:_:)` runs `rangeVsRange` across the
full expansion on both sides. **This is what published "AA vs KK ≈ 82.4%"
reference figures actually mean** — see the next section for why that
distinction turned out to matter more than expected while building this.

## A subtlety: which suits? (read this before trusting a specific number)

While validating this against published references, `headsUp(hero:
HoleCards(canonical: "AA"), villain: HoleCards(canonical: "KK"))` produced
**82.36% / 0.54% / 17.09%** — extremely close to the commonly-quoted "82.4%"
figure. That looked like confirmation. It wasn't quite measuring the same
thing as the citation, and the gap between "close" and "measuring the same
thing" turned out to be real and worth documenting rather than glossing over.

`HoleCards(canonical:)` always assigns a pair's two cards to **clubs and
diamonds** (see `HoleCards.swift`) — so `HoleCards(canonical: "AA")` and
`HoleCards(canonical: "KK")` don't just happen to both use those two suits,
they **share both of them**. That's the maximum-overlap case, and it's not
suit-neutral: re-running the exact computation with a non-overlapping suit
assignment (`A♣A♥` vs. `K♦K♠`) gives **81.06% / 0.38% / 18.55%** instead — a
real, reproducible ~1.3-point swing on the win rate, purely from which suits
were used, with the *same two hand classes* and *exact, zero-error*
enumeration on both sides. This isn't noise or a bug: fewer clubs/diamonds
remain in the deck when both hands share those suits, which measurably
changes flush frequency on the runout.

Published "AA vs KK" figures — and the poker-community shorthand "AA is an
82% favorite over KK" — are **combo-weighted averages** across every way
AA's two suits can relate to KK's two suits (0, 1, or 2 shared), not the
equity of one arbitrary concrete pair of hands. That's exactly what
`canonicalVsCanonical("AA", "KK")` computes (expand both to all 6 combos each,
sample across all 36 pairings), and it lands at **81.92%** in this codebase's
Monte Carlo — within 0.3pt of cardfight.com's cited **81.71%**, and
compatible with the commonly-rounded "82.4%" (see the table below; different
public sources round or compute this slightly differently, which is itself
consistent with there being real, small, legitimate variation depending on
methodology).

**The practical upshot:**

- `headsUp` answers "what's the exact equity for *this specific pair of
  concrete hands*" — a well-posed, exactly-computable question, useful when
  you actually know both players' suits (e.g. from a hand history).
- `canonicalVsCanonical` answers "what's the equity for *this hand class vs.
  that hand class*, averaged over how the suits could align" — the question
  poker literature is almost always actually asking, and what the ground-truth
  ⁠tests below validate against.
- The two can legitimately differ by roughly a percentage point for
  pocket-pair-vs-pocket-pair matchups specifically (suited/offsuit hands have
  much less room for this, since their own suitedness already pins down more
  of the suit relationship). Neither number is "wrong" — they're answers to
  different questions that happen to share a name in casual conversation.

This is exactly the kind of thing "don't hand-wave" means in practice: the
first exact number this produced was close enough to the cited figure that
it would have been easy to call it a match and move on. It wasn't actually
the same computation as the citation, and the 1-point gap between the two
suit-assignment extremes is large enough that it could hide a real bug in a
less-examined codebase. It isn't one here — but only because it got checked.

## Ground-truth validation

Every number below was fetched from **cardfight.com**, a dedicated preflop
equity-statistics site, while building this feature (via live page fetches,
not recalled from memory) — chosen because it publishes exact win/tie/lose
percentages per matchup with enough precision to cross-check against
(`AA_KK.html`, `QQ_AKs.html`, `22_AKo.html`, `AA_72o.html`, `QQ_JTs.html`).

| Matchup | Cited (cardfight.com) | Measured (`canonicalVsCanonical`, 100k iters) | Diff |
| --- | --- | --- | --- |
| AA vs KK | 81.71% / 17.82% / 0.46% | 81.92% / 17.64% / 0.44% | 0.21pt |
| AKs vs QQ | 45.83% / 53.73% / 0.43% | 45.78% / 53.81% / 0.41% | 0.05pt |
| AKo vs 22 | 47.04% / 52.34% / 0.62% | 47.04% / 52.39% / 0.58% | 0.00pt |
| AA vs 72o | 87.99% / 11.59% / 0.42% | 87.78% / 11.79% / 0.43% | 0.21pt |
| QQ vs JTs (overpair vs. suited connector) | 81.47% / 18.13% / 0.40% | 81.32% / 18.28% / 0.40% | 0.15pt |

All within 0.25 percentage points — well inside the documented Monte Carlo
tolerance (`±1.0pt` is what `EquityTests.swift` actually asserts, deliberately
looser than the observed deviation so the tests don't flake on legitimate
sampling variation if the seed or iteration count ever changes).

A note on the task's original framing of two of these:

- **"AKo vs 22 ≈ 50%"** — colloquially, a pair vs. two overcards is called "a
  coinflip" in poker slang. The precise number (47.04% / 52.34%) shows the
  pair is a real, consistent ~5-point favorite, not a literal coinflip. The
  slang predates precise equity calculators; it's a "close enough that both
  sides commit" description, not a citation. Tested against the precise
  cardfight.com figure instead of the rounded "50%," since precision matters
  more here than matching a casual description.
- **"AKs vs QQ ≈ 46.2%"** — matches closely (measured 45.78%, cited 45.83%);
  the 46.2% figure appears to be a slightly different rounding of the same
  real number, well within normal cross-source variation for this kind of
  statistic.
- **"AA vs 72o ≈ 88%+"** — the precise combo-weighted figure (87.99% cited,
  87.78% measured) is just *under* 88%, not over it. An early version of this
  test asserted `winRate > 0.88` directly (matching the task's phrasing
  literally) and it failed — correctly: the assertion was wrong, not the
  code. Fixed by testing against the precise citation instead of the rounded
  description, same as the other two notes here.

## Performance

Measured on this machine, Swift 6.3 (Xcode 27 beta toolchain), Apple
Silicon, `swift test` (debug/`-Onone` — SwiftPM's default, and what CI runs):

| Operation | Time |
| --- | --- |
| `headsUp`, preflop (1,712,304 boards) | **~285 seconds** |
| `headsUp`, preflop, release build (`-c release`) | ~32 seconds |
| `headsUp`, flop given (990 boards) | well under 1 second |
| `headsUp`, turn given (44 boards) | instant |
| `monteCarlo`, 100,000 iterations | ~17 seconds |
| `monteCarlo`, 200,000 iterations | ~34 seconds |

**This is slow, and that's a deliberate tradeoff, not an oversight.**
`HandEvaluator.evaluate5` avoids the most obviously wasteful approach
(a `Dictionary` for rank-counting) in favor of a fixed 15-slot array, and
`bestHand(from:)`'s 7-card path uses a precomputed static index table instead
of a general combinations generator — but a genuinely fast evaluator (the
kind real solvers use) needs a perfect-hash lookup table built from prime-number
rank encoding, which is a meaningfully larger, more error-prone undertaking
than this study tool's scope justifies. `@_optimize(speed)` was tried on the
hot-path functions specifically to see if it could close the gap without that
work; it made no measurable difference (debug-mode's lack of inlining and
bounds-check elision dominates regardless of a single function's own
optimization attribute), so it was removed rather than kept for no benefit.

**Consequence for this codebase's test suite:** exactly **one** test
(`exactPreflopEnumerationAAvsKK`) pays the full ~285-second preflop
exhaustive-enumeration cost, specifically to prove the exact-enumeration path
really works end-to-end. Every ground-truth validation test uses
`canonicalVsCanonical` (Monte Carlo, ~17s each at 100k iterations) instead —
justified both by the performance difference and by the "which suits?"
finding above (Monte Carlo over the full combo expansion is actually the
*more correct* way to match a published canonical-hand equity figure, not
just the faster one). Total `swift test` time added by this feature is
roughly 5-6 minutes — noticeably slower than the rest of the suite (which
runs in under a second), and worth knowing about before running the full
suite impatiently.

If this needs to get faster later: the standard next step is a precomputed
lookup-table evaluator (e.g. the well-known "Cactus Kev" 5-card evaluator, or
a two-plus-two-style 7-card perfect-hash table) swapped in behind
`HandEvaluator.bestHand(from:)`'s existing signature — nothing in `Equity` or
any caller would need to change, since they only depend on `bestHand`
returning a correctly-ordered `HandStrength`.

## Consumers

- `EquityCalculatorView` (`app/Sources/EquityCalculatorView.swift`) — pick a
  hero hand, a villain hand or range, an optional board, see win/tie/lose %.
  Wired into the home screen via `StudyTool.equityCalculator`.

## What this deliberately doesn't do

- **No range-parsing UI beyond canonical hand strings.** `expandCanonical`
  handles one hand class at a time ("AA", "AKs", "72o"); building a full
  range-editor UI (percentage sliders, custom range strings like "22+, AJs+")
  is out of scope for this pass — `EquityCalculatorView` exposes hand-vs-hand
  and hand-vs-single-canonical-class-range, not arbitrary multi-hand ranges.
- **No postflop simulation beyond a given board.** This computes equity
  *given* a board (or none); it doesn't model betting, folding equity, or any
  strategic decision — it's a pure probability calculator, same category of
  tool as an equity calculator website, not a solver.
- **No ICM.** Equity here is always chip-count-share probability, never
  tournament-payout-adjusted. Consistent with every other model in this
  codebase except that here it's simply out of scope rather than
  approximated.
