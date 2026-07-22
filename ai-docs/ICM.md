# The Independent Chip Model (ICM)

Source: `PokerKit/Sources/PokerKit/ICM.swift`, `ICMRiskPremium.swift`. Tests:
`ICMTests.swift`.

## What it does

Converts a set of tournament chip stacks and a payout structure into each
player's exact $EV — the **Malmuth-Harville method**, the standard
implementation of ICM used across the poker industry (HoldemResources
Calculator, ICMIZER, and every other ICM tool implement this same algorithm).
Chips aren't worth cash 1:1 once there's a payout structure on the table:
doubling your stack doesn't double your tournament equity, and busting
doesn't cost you your whole stack's worth of $EV if a chunk of that value was
"I'm guaranteed at least the min-cash" money that survives the bust. ICM
quantifies exactly how much.

**This is exact math, not a hand-tuned study aid** — the one model in this
codebase that isn't. Every other model here (`PushFoldRange`, `OpeningRange`,
`CallingRange`, `ThreeBetRange`, `FourBetRange`) encodes a percentage table
someone had to estimate; ICM equity is a specific, computable number once you
fix the stacks and payouts. `ICM.equities` computes it to floating-point
precision — there's no approximation to disclose about the core algorithm
itself (the approximations live one layer up, in `ICMRiskPremium` — see
below).

## The algorithm

For a field of `n` players with chip stacks `s₁...sₙ` and a payout table
`p₁...pₘ` (1st place first; a finishing position beyond `m` pays $0):

1. **P(a given player finishes 1st)** = their stack ÷ total chips in play.
2. **P(a given remaining player finishes 2nd)**, conditional on who finished
   1st = their stack ÷ the chips remaining *after removing the 1st-place
   finisher* (re-normalizing over what's left).
3. Recurse the same way for 3rd, 4th, ... down through every remaining
   player.
4. A seat's **equity** = Σ over every finishing position `k` of
   P(finish in position `k`) × `pₖ`.

This is exactly David Harville's 1973 method for predicting horse-race
finishing orders (stack size stands in for "horse strength"), adapted to
poker tournaments by Mason Malmuth in 1987 — hence "Malmuth-Harville."

### Implementation: bitmask memoization, not literal `n!` enumeration

The definition above, read literally, enumerates every one of the `n!`
possible finishing orders. `ICM.equities` computes the identical result
without doing that: the recursive sub-problem "compute equity contributions
from here" depends only on *which players are still uneliminated*, not on
the specific order that got them there — so it memoizes on that remaining-
player set (a bitmask), giving `O(2ⁿ × n²)` instead of `O(n!)`. For any
realistic final table (≤10 players) this is effectively instant; even 20
players — far beyond a real final table — stays comfortably sub-second. This
is not designed for, and not useful at, full-field sizes (hundreds of
entrants) — it's a final-table/bubble tool, matching how ICM is actually used
in practice (nobody runs ICM on a 500-entrant field at hand #1).

## Validation against a published worked example

**Source**: Wikipedia's ["Independent Chip Model"](https://en.wikipedia.org/wiki/Independent_Chip_Model)
article (fetched directly while building this feature). Its worked example:
three players A/B/C with chip stacks in a 50%/30%/20% split, payouts of 70
(1st) and 30 (2nd) — a 100-unit pool, 3rd place unpaid. The article publishes
(loosely rounded, using "≈" throughout): **A ≈ $45, B ≈ $32, C ≈ $22**.

This project independently re-derived the exact fractions by hand from the
same recursive definition above (shown here so the arithmetic is checkable
without running any code):

```
P(A 1st) = 1/2,  P(B 1st) = 3/10,  P(C 1st) = 1/5

Given A 1st (remaining B=3/10, C=1/5, sum=1/2):
  P(B 2nd | A 1st) = 3/5,  P(C 2nd | A 1st) = 2/5
Given B 1st (remaining A=1/2, C=1/5, sum=7/10):
  P(A 2nd | B 1st) = 5/7,  P(C 2nd | B 1st) = 2/7
Given C 1st (remaining A=1/2, B=3/10, sum=4/5):
  P(A 2nd | C 1st) = 5/8,  P(B 2nd | C 1st) = 3/8

P(A 2nd) = P(B1)(5/7) + P(C1)(5/8) = 3/14 + 1/8 = 19/56
P(B 2nd) = P(A1)(3/5) + P(C1)(3/8) = 3/10 + 3/40 = 3/8
P(C 2nd) = P(A1)(2/5) + P(B1)(2/7) = 1/5 + 3/35 = 2/7

Equity A = 70(1/2) + 30(19/56) = 35 + 570/56 = 1265/28 ≈ 45.1786
Equity B = 70(3/10) + 30(3/8)  = 21 + 90/8  = 129/4  = 32.25
Equity C = 70(1/5) + 30(2/7)   = 14 + 60/7  = 158/7  ≈ 22.5714

Check: 1265/28 + 129/4 + 158/7 = 1265/28 + 903/28 + 632/28 = 2800/28 = 100 ✓
```

`ICMTests.threeHandedWorkedExampleMatchesWikipediasPublishedICMArticle`
checks `ICM.equities` against **both**: the published rounded figures (loose
tolerance, since the source itself only publishes to the nearest dollar —
its `$22` is actually `$22.57` rounded down, so that specific comparison
needs a wider band than the other two) and the exact fractions above (tight,
`1e-9`, this project's own independently-checkable arithmetic — the real
precision validation). A second worked example
(`threeHandedWorkedExampleWithThreePaidPlacesMatchesHandDerivedFractions`)
uses the same 50/30/20 stack split against a 3-paid-place 50/30/20 payout
(`$5375/14, $655/2, $2020/7` on a $1000 pool) — hand-derived the same way, not
third-party-sourced, but included because the Wikipedia example only pays 2
places and never exercises the recursion's 3rd-place branch.

Other correctness gates in `ICMTests.swift`:
- **Equal stacks split equity equally** (2 through 6 players) — provable by
  symmetry, no citation needed.
- **The 2-player closed form**, `equity = (own/(own+other))·p1 +
  (other/(own+other))·p2`, checked against the general algorithm's output.
- **Total equity conservation**: equities always sum to exactly the prize
  pool being played for, across a battery of varied stack/payout shapes.
- **The "ICM tax"**: in a top-heavy payout structure, the chip leader's `$`
  per chip is *lower* than the short stack's — the core qualitative fact ICM
  exists to capture, asserted directly rather than just implied by the
  numbers matching.

## ICM risk premium — `ICMRiskPremium`

Applies ICM to the most common practical question it answers: **is calling
this all-in still profitable once tournament payout pressure is accounted
for, or does chip-EV alone overstate it?** Near a bubble or a real payout
jump, ICM makes calling shoves *tighter* than chip-EV suggests — busting
doesn't just cost chips, it costs your shot at the min-cash and every payout
jump above it.

**This is an overlay, not a replacement** — same shape as `BountyEquity`
(see `BOUNTY.md`). It never touches `ICM`, `PushFoldRange`, or
`CallingRange`; it's a separate opinion computed from `ICM.equities` that a
caller can consult *alongside* the existing chip-EV calling models, not
instead of them. Nothing in this codebase's calling ranges is mutated by
this module existing.

### The math

For hero facing a `villainStack`-sized all-in (full-stack shove/call — see
"What this simplifies away" below), with `otherStacks` unaffected by the
outcome and a `payouts` table:

- **Chip-EV breakeven** (ignoring ICM): `heroStack / (heroStack +
  villainStack)` — a pot-odds number. Note this *isn't* flat 50% even
  without ICM: a shorter stack needs less than 50% equity to profitably call
  off its whole stack (a bigger stack risks a lot to win comparatively
  little, so it needs more than 50%), which is standard push/fold theory,
  not new to this module.
- **ICM breakeven**: solve for the win probability `p` where `EV(call) =
  EV(fold)` in ICM-dollar terms. Since `EV(call) = p·winEquity + (1-p)·loseEquity`
  is linear in `p`, this has a closed form:
  `p = (foldEquity − loseEquity) / (winEquity − loseEquity)`, where:
  - `foldEquity` = hero's `ICM.equities` share of the field with stacks
    unchanged.
  - `winEquity` = hero's share after absorbing villain's stack (villain
    removed from the field).
  - `loseEquity` = **fixed at 0** — see below.
- **Risk premium** = `ICM breakeven − chip-EV breakeven`. Positive in the
  standard "protect your stack near a payout jump" case;
  `ICMTests.icmRequiredEquityIsUnaffectedWhenNothingIsAtStakeBeyondTheConfrontation`
  checks it collapses to exactly 0 in the one case where it provably should
  (heads-up, single payout, nothing else alive — no bubble to protect).

### What this deliberately simplifies away

Every one of these is a disclosed scope limitation, not an oversight — also
stated directly in `ICMRiskPremium`'s doc comment so it's visible at the call
site, not just here:

- **A single all-in for full stacks.** One hero-vs-villain confrontation,
  loser fully eliminated, winner absorbs the loser's entire stack. No side
  pots, no covering/covered partial-stack all-ins, no multi-way pots.
- **Busting means $0, not a guaranteed min-cash.** `loseEquity` is fixed at
  `0` rather than computed — a real tournament often still pays a busted
  player *something* (the min-cash for whatever place they finish, even at
  0 chips), which this module doesn't model because doing so correctly
  needs the full remaining payout ladder and how many total entrants have
  already busted overall — information this module doesn't have and doesn't
  ask for. Net effect: **this model slightly overstates the true risk
  premium** (the real gap between chip-EV and ICM is a bit smaller than what
  it reports), since it treats every bust as forfeiting money a real min-cash
  floor would sometimes have protected. This is the same simplification
  common introductory ICM risk-premium explanations make.
- **No Future Game State (FGS).** Doesn't model that winning also improves
  hero's *position* for every hand after this one (a bigger stack means
  better odds in `PushFoldRange`/etc. going forward) — only this one all-in's
  direct $EV.
- **`otherStacks` must be the entire remaining field.** If players are alive
  elsewhere in the tournament not included in `otherStacks`, the computed
  premium is wrong. This matches `ICM.equities`'s own scope — a final-table/
  complete-remaining-field tool, not a partial slice of a larger field.

## Consumers

- Planned: an ICM Calculator view (stacks + payouts in, per-seat $EV out) —
  see the app's `StudyTool` list.

`ICM.equities` and `ICMRiskPremium.assess` are both pure functions with no
dependency on anything else in `PokerKit` beyond `Foundation` — they don't
reuse `ChenScore`/`PushFoldRange`'s threshold pipeline the way every other
model in this codebase does, because ICM isn't a hand-ranking problem at all;
it only ever operates on chip stacks and payouts.
