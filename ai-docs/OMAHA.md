# Omaha / PLO — Phase 1: Hand Foundation, Evaluation, Equity

Source: `PokerKit/Sources/PokerKit/OmahaHoleCards.swift`,
`OmahaHandEvaluator.swift`, `OmahaEquity.swift`. Tests:
`OmahaHoleCardsTests.swift`, `OmahaHandEvaluatorTests.swift`,
`OmahaEquityTests.swift`.

This is the first phase of a new track: Omaha/PLO support, **added alongside**
every existing Hold'em (NLHE) model, never replacing or modifying it.
`ChenScore`, `PushFoldRange`, `OpeningRange`, `CallingRange`, `ThreeBetRange`,
`FourBetRange`, `Equity`, `HandEvaluator`, `ICM`, `GameFormat` — all untouched.
See "Why a new foundation, not a reuse" below for exactly why Omaha can't
just plug into those.

## What Omaha is, for anyone coming from this codebase's Hold'em-only history

Omaha (specifically **Pot-Limit Omaha**, PLO, the dominant variant) deals
each player **4 hole cards** instead of Hold'em's 2, but changes the hand-
construction rule to compensate: the best 5-card hand must use **exactly 2**
of the 4 hole cards and **exactly 3** of the 5 board cards — never more,
never fewer of either. A hole card you don't use is simply dead; you can't
"borrow" a 3rd hole card even if it would make a better hand, and you can't
play the board alone. This single rule is the entire difference from
Hold'em's "best 5 of any 7" — and it has real consequences: having 4 hole
cards *sounds* like more outs, but the 2-card cap means many apparently-
strong 4-card hands (three or four cards of one suit, three-of-a-kind in
hole cards) are structurally much weaker than they look, because at most 2
of those cards can ever combine.

## Why a new foundation, not a reuse of the NLHE models

- **`ChenScore` has no meaning for 4 cards.** It's specifically a 2-card
  heuristic (high card + pair bonus + suited bonus + gap penalty between
  *two* ranks) — there's no well-defined way to extend it to a 6-way
  combination of 4 ranks without inventing a new scoring system, which is
  exactly the kind of judgment call this project deferred to Phase 2 (see
  below).
- **Every range model built on `ChenScore`/`PushFoldRange.scoreThreshold`**
  (`OpeningRange`, `CallingRange`, `ThreeBetRange`, `FourBetRange`) inherits
  that same limitation — none of them can be pointed at a 4-card hand.
- **`HandEvaluator.bestHand(from:)` alone would silently produce wrong
  answers for Omaha** if handed a hole+board pool directly (its whole
  contract is "best 5 of however many you give it," with no way to express
  "but only 2 may come from this subset") — using it correctly for Omaha
  needs an enumeration layer on top, which is exactly what
  `OmahaHandEvaluator` is. `HandEvaluator` itself is unmodified and still
  does 100% of the actual 5-card ranking.

## `OmahaHoleCards`

Four hole cards, stored canonically (rank-descending, then suit) so
`OmahaHoleCards` built from the same 4 cards in any input order compare
equal and hash identically — a deliberate improvement over `HoleCards`
(which doesn't normalize `first`/`second` order), justified by the fact that
a 4-card hand has no natural "first/second" the way two hole cards do.

**Notation**: an explicit 8-character per-card token, e.g. `"AsAhKdQc"` —
unambiguous, exactly round-trips through `init(canonical:)`. This project
deliberately did **not** invent a Hold'em-style compact shorthand
("AAKQds" or similar) for Phase 1: unlike Hold'em's "s"/"o" suffix (a single
well-known industry standard), there's no equally standardized short-form
for a 4-card hand's suit structure — PLO training material writes hands out
in various ways (explicit cards, "AAKK double-suited," "AAKKds," rank-
pattern-plus-suit-count) without one clearly dominant convention. Inventing
one and presenting it as *the* canonical form would be exactly the kind of
unforced judgment call this phase is trying to avoid. `Card(notation:)` (a
small new addition, e.g. `"As"`, `"Th"`) backs this — it lives in
`OmahaHoleCards.swift` rather than `Card.swift` itself, matching
`HoleCards.swift`'s own precedent of hosting `Rank.from(symbol:)` alongside
the type that first needs it, keeping `Card.swift` untouched.

**`suitPattern`** (`.doubleSuited`/`.singleSuited`/`.rainbow`) is a
descriptive, computed-from-the-cards label — not part of the parseable
notation — matching how PLO players actually talk about a hand's suit
shape. Documented caveat: `.singleSuited` also covers 3-flush/4-flush hands
(3 or 4 cards sharing one suit), which are structurally weaker than a clean
2-and-2 single-suited hand (only 2 of the same-suited cards can ever be used
together — see `OmahaHandEvaluator`) even though this label doesn't
distinguish them. That distinction is a strength judgment, not a structural
fact, and belongs with Phase 2's hand-strength work, not here.

## `OmahaHandEvaluator` — the 2-hole/3-board rule

`OmahaHandEvaluator.bestHand(hole:board:)` enumerates all `C(4,2) × C(5,3) =
6 × 10 = 60` legal 5-card combinations for a **completed** (5-card) board,
handing each one to the unmodified `HandEvaluator.bestHand(from:)`, and
keeps the best. Requires a full river board (unlike `HandEvaluator.bestHand`,
which accepts 5-7 cards) — Omaha's 2-and-3 split is only meaningful against
a specific board size; "best legal hand on the turn" is an `OmahaEquity`-
level concept (averaging over every possible river), not something this
function does itself.

### Proving the rule is actually enforced

Three tests exist specifically to catch the failure mode where this
constraint is silently ignored or partially wrong — not just checking "this
hand evaluates to something reasonable," but constructing spots where the
*illegal* answer and the *correct* answer are dramatically, obviously
different:

- **`fourAcesInHoleCanOnlyEverPlayExactlyTwoOfThem`**: hole = all four aces
  (one per suit — a legal, if unusual, Omaha hand). Board: five cards, all
  distinct non-ace ranks, no board pair. If the 2-card cap were ignored,
  the best 9-card hand would be trips or quads. The evaluator must return
  exactly a pair of aces — provable by hand, since two of the five final
  cards are always both "Ace" (from whichever 2 of the 4 hole aces are
  picked) and the board contributes no pair of its own.
- **`fourSpadesInHoleDoNotMakeAFlushWithOnlyOneSpadeOnBoard`**: hole =
  A♠K♠Q♠J♠, board = T♠ plus four off-suit unpaired cards. Ignoring the
  2-card cap, this is a **royal flush** (A-K-Q-J-T all spades) — but that
  uses 4 hole cards, illegal. Correctly enforced, at most 2 hole spades + 1
  board spade can ever appear together (3 spades, never 5) — the evaluator
  must return exactly High Card, never a flush or straight flush.
- **`aQueenHighStraightFlushIsCorrectlyFoundWhenTheSplitGenuinelyAllowsIt`**:
  the positive counterpart — same four spades in hole, but a board of
  T♠9♠8♠7♠6♠ (five consecutive spades). Here a *legal* straight flush
  genuinely exists (hole Q♠J♠ + board T♠9♠8♠ = queen-high straight flush),
  proving the evaluator isn't just pessimistic, it correctly finds a legal
  nut hand when one is actually reachable within the rule.
- **`evaluatesExactlySixtyCombinationsAndPicksTheirMaximum`**: a brute-force
  cross-check, re-implementing the same 60-combination enumeration
  independently in the test itself and confirming both agree — so the
  production code's precomputed index tables aren't just trusted at face
  value.

## `OmahaEquity`

Same two-mode shape as `Equity` (`headsUp` exact, `monteCarlo` fixed-seed
sampled), built on `OmahaHandEvaluator` instead of `HandEvaluator` directly.

**No `expandCanonical`/`canonicalVsCanonical` equivalent** — this module
only ever takes concrete `OmahaHoleCards` or lists of them, never a
hand-class string. Building an Omaha canonical-hand-class abstraction (the
4-card equivalent of expanding "AKs" into its 4 concrete combos) requires
first deciding what a "canonical Omaha starting hand" even means for
equity-aggregation purposes — itself hand-strength/classification judgment,
deferred to Phase 2.

### Performance — exact enumeration is tighter here than in Hold'em

`OmahaEquity.headsUp` (exact) costs `120` 5-card evaluations per board
completion (`60` per side, `OmahaHandEvaluator`'s own enumeration) versus
Hold'em's `42` (`HandEvaluator`'s unrestricted 21-combination 7-card
`bestHand`) — and Omaha's 8 known hole cards (4 per side) leave fewer cards
to draw the rest of the board from, so preflop there are *more* boards to
enumerate too: `C(44,5) = 1,086,008` vs. Hold'em's `C(48,5) = 1,712,304`.
Net effect: an exact preflop `OmahaEquity.headsUp` call does roughly **2×**
the raw work of the already-slow (several minutes, per `EQUITY.md`) Hold'em
equivalent — likely 10+ minutes for one matchup. **This project deliberately
never calls `headsUp` preflop** — not in a test, not from the app.
`monteCarlo` is the tool for that (and is what every equity validation below
actually uses).

**Postflop isn't uniformly "instant" either — flop-exact measurably isn't.**
A given river (0 completions) or turn (≤40 completions) is fast, and this
codebase's own tests only exercise `headsUp` at those depths. A given
*flop* still needs `C(41,2) = 820` completions × 120 evaluations — cheap in
absolute terms, but building the app's Omaha equity screen surfaced that
this measured **close to, and on one run over, a 30-second UI-test
timeout** on a debug build running on the iOS Simulator (vs. Hold'em's own
flop-exact, a genuinely fast 42-evaluations-per-board computation that
comfortably clears the same kind of timeout in `EquityCalculatorView`'s own
tests). The app's Precise mode still offers flop-exact (it does eventually
complete), but treat it as "tractable, not instant," and the UI test that
proves Precise mode works uses a river-given board specifically to avoid
being a flaky benchmark of flop-exact's on-device timing rather than a
correctness check.

## Validation

### What a citable, precise number turned out to look like for PLO

Unlike `RANGES.md`'s opening-range anchor (one source, fetched twice,
identical numbers both times) or `ICM.md`'s worked example (an exact
published fraction, independently re-derivable by hand), **no single source
with a precisely stated PLO equity figure and a fully specified matchup**
was found via web search. Multiple PLO strategy sites cite AAKK
double-suited's equity against a random hand anywhere from **64% to 73%**
depending on the source, with no agreement on methodology (sample size,
which random-hand universe, exact suit assignment). Per this project's own
rule (a bad number is worse than none — see `CLAUDE.md`), that spread is too
wide to validate a specific decimal against.

**What *was* consistently repeated across independent sources** (found via
web search, e.g. pokerlistings.com's "Pot-Limit Omaha: Top 30 Starting
Hands" and corroborated by others): **AA-KK double-suited is only a 3-2
favorite over a strong double-suited rundown like 8-7-6-5** — the classic
illustration of how much closer premium-vs-premium equities run in Omaha
than in Hold'em. "3-2" is a ratio, not a decimal (`3/(3+2) = 60%`), and no
source specified the exact suit-pairing of the rundown (8-7-6-5 double-
suited has more than one way to pair 2 suits across 4 ranks) — so this is
used as a **directional, wide-tolerance** check, not a tight one:

```
aakk = "AsKsAhKh"   (aces and kings, paired across spades/hearts)
rundown = "8s7s6h5h" (8-7 spades, 6-5 hearts — one reasonable pairing;
                      exact pairing wasn't specified in any source found)

OmahaEquity.monteCarlo(hero: [aakk], villain: [rundown], iterations: 50,000)
  → win 61.96%, tie 0.00%, lose 38.04%
```

**61.96% lands almost exactly on the cited "~60% / 3-2" figure** — well
within the wide (52-68%) band the test checks, and close enough to the
specific cited ratio that this project is confident the model is directionally
and quantitatively sound, not just "in the right ballpark." A companion
test (`aacesKingsBeatsAWeakRandomHandMoreConvincinglyThanATopRundown`, no
citation needed) checks the model gets the *shape* right too: AAKK should
run better against unconnected junk than against a premium rundown, which
it does.

### Hand-verifiable exact tests (the primary correctness gate)

Per this project's own fallback rule when no solid citation exists ("pick a
hand-verifiable spot rather than assert an unsourced number" — this
document's own governing instruction), two tests carry the real weight of
proving `OmahaEquity` is *exactly* correct, not just directionally
plausible, with a complete board (0 sampling, 1 trial, deterministic):

- **`heroWithLockedQuadsWinsWithCertaintyOnACompleteBoard`**: hero holds
  the other two of a rank the board already pairs (board shows two sevens;
  hero holds the remaining two sevens) — hero's best legal hand is provably
  quad sevens (2 hole + the board's 2 + 1 more board card), and villain
  (holding no sevens) can never do better than a plain pair of sevens off
  the same board pair. Asserts `winRate == 1.0` exactly.
- **`mirroredSuitHandsOnASuitNeutralBoardTieWithCertainty`**: hero and
  villain hold the identical 4 ranks (A,K,Q,J) in different suits (spades
  vs. hearts), on a board with zero spades and zero hearts. Neither side can
  ever complete a flush, so every legal 5-card combination either side can
  form has an exact mirror on the other side — a tie *by symmetry*, not
  coincidence, asserted as `tieRate == 1.0` exactly.

Both are provable by direct reasoning about the specific cards involved, no
external source required — exactly the "pure board-lock" style fallback this
phase's own scope called for.

## What Phase 2 should be (and why it's scoped separately)

**PLO preflop hand-strength / starting-hand ranges.** This is the natural
next piece — a way to say "this 4-card hand is strong/weak preflop," the
Omaha equivalent of `ChenScore` + `PushFoldRange`/`OpeningRange` — and it's
**judgment-heavy in a way Phase 1 deliberately wasn't**:

- Chen's heuristic doesn't extend to 4 cards (see above) — a genuinely new
  scoring approach is needed, not a reuse. Real Omaha hand-strength
  heuristics that do exist (e.g. various "Omaha hand value" formulas found
  in strategy literature) are **themselves competing, disputed heuristics**,
  not an agreed-upon standard the way Chen's is for Hold'em — meaning
  *choosing which one to use* is itself a disclosed, debatable judgment
  call, before any percentage tables even enter the picture.
- Every downstream number this project would build on top (push/fold
  threshold, opening threshold, defending ranges) would inherit that
  foundational uncertainty, compounding across the same "which numbers are
  sourced vs. hand-tuned" honesty this project already applies rigorously
  elsewhere (`RANGES.md`) — worth scoping and flagging deliberately as its
  own phase rather than backing into it as a side effect of "add ranges next."
- Concretely, Phase 2 should: (1) pick and disclose one hand-strength
  heuristic (or build a simple one from first principles — e.g. equity vs.
  a random hand, computed via `OmahaEquity.monteCarlo`, as the ranking
  signal itself, which has the advantage of being *this project's own exact
  math* rather than a second borrowed heuristic), (2) validate it against
  known strong/weak Omaha starting hands directionally (AAKK ds ranks
  higher than 7532 rainbow, etc.), (3) only then build push/fold-style
  threshold tools on top, with every percentage explicitly flagged as
  hand-tuned, the same posture `RANGES.md` already takes for Hold'em.

This is **not started in this PR** — Phase 1 stops at foundation +
evaluation + equity, a complete and independently useful/testable slice.

## Consumers

- Minimal Omaha equity screen in the app (see `StudyTool`) — enter two
  explicit hole-card notations and an optional board, get win/tie/lose via
  `OmahaEquity.monteCarlo` (or exact once the board is complete). No
  preflop "Precise" mode is offered — see the performance note above for
  why that would hang the UI.
