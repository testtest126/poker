# PKO Bounty-Adjusted Shove Ranges

Source: `PokerKit/Sources/PokerKit/BountyEquity.swift`. Tests:
`BountyEquityTests.swift`. Builds on `PushFoldRange.swift` (see
`RANGES.md`) without modifying it.

## What it does

In a PKO (progressive knockout) tournament, busting a covered opponent wins
their bounty on top of the pot. A pure chip-EV model like `PushFoldRange`
has no way to see that — it only ever reasons about chips — so it
systematically **under-shoves and under-calls** relative to what's actually
correct in a bounty tournament. `BountyEquity` is a widening overlay: given
a base chip-EV shove percentage, it returns a wider one that accounts for
the extra equity a collectible bounty adds.

**This is a hand-tuned study aid, not solver output** — same posture as
every other model in this codebase, and for a sharper reason than most:
real PKO strategy is the net effect of *two competing forces* (see
"Scope and honest limitations" below), and this module only implements one
of them.

## The formula — read this before trusting a specific number

The standard treatment found across PKO strategy sources (see "Source
basis" below) folds a bounty into an all-in decision by adding its
chip-equivalent value to the pot on the winning side of a pot-odds
calculation:

```
requiredEquity = amountToCall / (potAfterCalling + bountyValueInChips)
```

Compare this to the no-bounty case, `requiredEquity = amountToCall /
potAfterCalling`. Dividing one by the other gives the **threshold
multiplier** this module actually computes:

```
thresholdMultiplier = pot / (pot + bounty)
```

Multiplying a required-equity threshold by this factor (always in `(0, 1]`)
lowers it — exactly the standard result that a bounty makes it correct to
get all-in with a weaker hand than chip-EV alone would justify. This
codebase doesn't compute literal win-probability equity anywhere (`ChenScore`
is a hand-strength *ranking*, not an equity model — see `RANGES.md`), so
`BountyEquity` doesn't apply this multiplier to a raw equity number. Instead
it applies the **reciprocal** to a **percentage of hands** — `PushFoldRange`'s
existing "shove the top X%" percentage — which is the quantity that actually
flows into this codebase's decision pipeline
(`PushFoldRange.scoreThreshold(forPercentage:)`). A smaller required-equity
threshold and a larger "percentage of hands that clear the bar" are the same
underlying fact stated two different ways; scaling the percentage by the
reciprocal of the equity multiplier is the natural translation of the
sourced formula into the vocabulary this codebase already uses everywhere
else, not a new formula.

```
widenedPercentage = min(basePercentage / thresholdMultiplier, 100)
                   = min(basePercentage × (pot + bounty) / pot, 100)
```

### `pot` is approximated as `2 × effectiveStackBB`

The sourced formula needs a pot size, and nothing in this codebase currently
threads a real pot-size parameter through `PushFoldRange` (it only ever
takes position + effective stack — see `RANGES.md`). Rather than invent a
new required input, `BountyEquity` approximates the all-in pot as hero's
shove plus a covering call — `2 × effectiveStackBB` — and ignores
blinds/antes already in the middle. This is a standard simplification for
short-stack push/fold math: blinds/antes are a small fraction of the pot at
the stack depths `PushFoldRange` covers (1–20bb), and `PushFoldRange` itself
already abstracts them away. **Treat this as the model's least-precise
input** — a spot with unusually large antes relative to the stack (very late
in a tournament) will be slightly under-widened by this approximation.

## Source basis

- **The core formula** — `requiredEquity = amountToCall / (pot + bounty ×
  bountyPower)` — comes from GTO Wizard's "The Theory of Progressive
  Knockout Tournaments" (`blog.gtowizard.com`), found via web search while
  building this feature. The article works a full numeric example: a $50
  bounty converted through a "bounty power" figure of 0.191 (bb per dollar)
  adds 9.55bb to the pot side of the calculation, dropping the required
  equity to call from 43.6% to 32.4% in that specific spot. This module
  implements the same algebraic shape (`pot` and `pot + bounty` on either
  side of a ratio) with the bounty already expressed in bb — `bountyBB` is
  this module's equivalent of that article's `bounty × bountyPower`.
- **The general "bounty widens ranges" qualitative fact** — corroborated
  independently across multiple sources found via web search (Red Chip
  Poker's "Quantifying the Value of the Bounty in Knockouts",
  BeyondGTO's PKO strategy guide, bbzpoker's PKO tournament guide): all
  describe converting a bounty to a chip-equivalent value and adding it to
  what's won on a knockout, all agree the effect is a wider profitable
  range early in a PKO. None of these sources gave a second, independently
  checkable formula to cross-verify the GTO Wizard one against — this
  module's precision is bounded by having one real source for the exact
  math, not several agreeing ones (contrast with `RANGES.md`'s opening-range
  100bb anchor, which was cross-verified via two fetches of the same
  source).

## Scope and honest limitations

- **Only applies when hero covers villain.** If hero doesn't cover villain,
  winning the pot doesn't eliminate them — no bounty is collectible, so
  `heroCoversVillain: false` is defined to produce *no adjustment at all*,
  identical to the base `PushFoldRange` decision. This is enforced in code,
  not just documented: `thresholdMultiplier`/`widenedPercentage` both
  short-circuit to a no-op the moment `heroCoversVillain` is `false`.
- **Being covered is out of scope, on purpose.** The flip side of this
  module — hero risking their own bounty, and the ICM-like risk of being
  eliminated — is a *negative* adjustment (should *tighten* a range) that
  this module makes no attempt to compute. GTO Wizard's own PKO material
  (`blog.gtowizard.com/how-does-icm-impact-pko-strategy/`) frames real PKO
  strategy as the net of exactly two competing forces: a bounty-equity
  widening for the stack you can cover (what this module computes) and an
  ICM-style tightening for the stack that could cover *you*. This module
  implements the first and explicitly not the second — a real spot where
  neither player fully covers the other needs both, and this module alone
  will overstate how wide to play.
- **No ICM at all**, beyond the bullet above — same posture as every range
  model in this codebase (`PushFoldRange`/`OpeningRange`/`CallingRange` are
  all pure chip-EV; see `RANGES.md`). A bounty-and-ICM-aware model would
  need real ICM math, which doesn't exist anywhere in `PokerKit` yet.
- **Assumes the whole bounty is realized on a win.** Real PKO bounties are
  often split (e.g. "50% of the bounty pays out immediately, 50% rolls onto
  the winner's own head" in some structures) — this module treats
  `bountyBB` as the full amount hero collects, so a split-bounty structure
  needs the caller to pass in only the immediately-collectible portion.
- **Ignores stack dynamics across a whole tournament** — bounty value
  relative to the blinds changes as the tournament progresses (antes and
  blinds grow, hero's own bounty grows if they've been knocking players
  out); this module is a single-spot calculation, not a tournament-long
  strategy.
- **The calling side isn't wired up yet.** `widenedPercentage` is written
  generically (it takes any base percentage, not specifically
  `PushFoldRange`'s), so it composes with a calling-range percentage the
  same way it composes with a shoving one — but this codebase's calling
  model (`CallingRange`) isn't on `main` yet (open in a separate PR). This
  module's `decide(...)` convenience function only wires up the shove side
  for now; extending it to calling once `CallingRange` lands is a follow-up,
  not a redesign.

## The pipeline

1. `PushFoldRange.shovePercentage(position:effectiveStackBB:)` — the base
   chip-EV percentage, unmodified, reused directly.
2. `BountyEquity.thresholdMultiplier(effectiveStackBB:bountyBB:heroCoversVillain:)`
   — `pot / (pot + bounty)`, or `1` (no-op) if there's nothing to adjust for.
3. `BountyEquity.widenedPercentage(...)` — the base percentage divided by
   that multiplier (i.e. multiplied by its reciprocal), clamped to 100.
4. `PushFoldRange.scoreThreshold(forPercentage:)` — reused directly, exactly
   as `OpeningRange` and `CallingRange` already do; still the only
   percentage → Chen-score-cutoff conversion in this codebase.
5. `BountyEquity.decide(hand:position:effectiveStackBB:bountyBB:heroCoversVillain:) ->
   BountyAdjustedDecision` — shoves if `handScore >= adjustedThreshold`.
   Returns a dedicated result type (not `PushFoldDecision`) specifically so
   a bounty-adjusted decision can never be silently mistaken for a plain
   chip-EV one — its `reasoning` text always states explicitly whether a
   bounty was entered, whether it was collectible, and by how much it moved
   the threshold.

## Consumers

- `PreflopRangeView`'s Push/Fold mode — an optional bounty overlay: a
  toggle, a bounty-size control, and a "you cover villain" toggle. When
  enabled, hands that only shove *because of* the bounty (fold in the base
  model, push in the bounty-adjusted one) render in a third, distinct grid
  color, so the widening is visible directly rather than just described in
  a percentage. A persistent caveat line links back to this document.

Nothing here mutates `PushFoldRange` — `bountyBB: 0` is a proven exact
no-op (`decideWithZeroBountyReproducesPushFoldRangeExactly`), so the plain
chip-EV tool is unaffected by this module existing.
