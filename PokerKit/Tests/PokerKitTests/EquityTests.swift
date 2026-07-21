import Testing
@testable import PokerKit

/// Tolerance for the canonical-hand-vs-canonical-hand Monte Carlo ground-truth checks
/// below. At `Equity.defaultMonteCarloIterations` (50,000) the standard error is roughly
/// 0.3-0.5%; the tests here use a larger explicit sample (100,000) for extra margin and
/// assert to `±1.0` percentage points — comfortably wider than the actual measured
/// deviation from the cited reference numbers (all under 0.3pt in practice; see
/// EQUITY.md's "Ground-truth validation" table for the exact figures found while building
/// this). Fixed seed means these never flake: the same call always returns the same number.
private let groundTruthTolerance = 1.0
private let groundTruthIterations = 100_000

private func assertApproximately(_ actual: Double, _ expectedPercent: Double, tolerance: Double = groundTruthTolerance) {
    let actualPercent = actual * 100
    #expect(
        abs(actualPercent - expectedPercent) <= tolerance,
        "expected \(expectedPercent)% ± \(tolerance)%, got \(actualPercent)%"
    )
}

// MARK: - Ground-truth validation (the whole point of this module)
//
// Every expected number below is cross-checked against cardfight.com's published preflop
// equity pages (fetched while building this feature) — see EQUITY.md for the full citation
// list and a table comparing cited vs. measured numbers.

@Test func groundTruthAAvsKK() {
    // Cited: AA 81.71% / KK 17.82% / tie 0.46% (cardfight.com). Commonly rounded elsewhere
    // to "82.4%" — see EQUITY.md for why both figures are compatible with what's measured
    // here (this is the combo-weighted number; a single specific suit assignment can
    // legitimately land up to ~1pt away from it — see the flagship exact test below).
    let result = Equity.canonicalVsCanonical("AA", "KK", iterations: groundTruthIterations)
    assertApproximately(result.winRate, 81.71)
    assertApproximately(result.loseRate, 17.82)
}

@Test func groundTruthAKsVsQQ() {
    // Cited: QQ 53.73% / AKs 45.83% / tie 0.43% (cardfight.com) — matches the task's own
    // "≈46.2%" description within the stated tolerance.
    let result = Equity.canonicalVsCanonical("AKs", "QQ", iterations: groundTruthIterations)
    assertApproximately(result.winRate, 45.83)
    assertApproximately(result.loseRate, 53.73)
}

@Test func groundTruthAKoVsPocketTwos() {
    // Cited: 22 52.34% / AKo 47.04% / tie 0.62% (cardfight.com). Colloquially called "a
    // coinflip" in poker slang, but the precise number is a real ~5-point favorite to the
    // pair, not literally 50/50 — see EQUITY.md.
    let result = Equity.canonicalVsCanonical("AKo", "22", iterations: groundTruthIterations)
    assertApproximately(result.winRate, 47.04)
    assertApproximately(result.loseRate, 52.34)
}

@Test func groundTruthAAvsSevenDeuceOffsuit() {
    // Cited: AA 87.99% / 72o 11.59% / tie 0.42% (cardfight.com). The task's own "88%+"
    // description rounds up very slightly — the precise combo-weighted figure is just
    // under 88%, not over it (measured 87.78% here); asserted against the precise citation
    // rather than the rounded description, same call made for "AKo vs 22 ≈ 50%" — see
    // EQUITY.md.
    let result = Equity.canonicalVsCanonical("AA", "72o", iterations: groundTruthIterations)
    assertApproximately(result.winRate, 87.99)
    assertApproximately(result.loseRate, 11.59)
}

@Test func groundTruthOverpairVsSuitedConnector() {
    // The "suited connector vs. overpair" case: QQ vs JTs. Cited: QQ 81.47% / JTs 18.13% /
    // tie 0.40% (cardfight.com).
    let result = Equity.canonicalVsCanonical("QQ", "JTs", iterations: groundTruthIterations)
    assertApproximately(result.winRate, 81.47)
    assertApproximately(result.loseRate, 18.13)
}

// MARK: - Flagship exact enumeration test
//
// Slow — full preflop board enumeration, C(48,5) = 1,712,304 boards, taking on the order of
// minutes in a debug build (see EQUITY.md's performance note for measured timing). Kept as
// exactly one test, not five, specifically to demonstrate `headsUp`'s exact-enumeration path
// really works end-to-end without making the whole suite unbearably slow — the ground-truth
// checks above cover the "does this match reality" question via fast Monte Carlo instead.

@Test func exactPreflopEnumerationAAvsKK() {
    // This is a SPECIFIC suit assignment (both hands use clubs+diamonds — the pair the
    // convenience of `HoleCards(canonical:)` init always produces), not the combo-weighted
    // canonical figure `groundTruthAAvsKK` checks above — see EQUITY.md's "A subtlety:
    // which suits?" section for why these are legitimately different numbers, and why an
    // exact zero-sampling-error computation is still the right thing to assert tightly.
    let aa = HoleCards(canonical: "AA")!
    let kk = HoleCards(canonical: "KK")!
    let result = Equity.headsUp(hero: aa, villain: kk)

    #expect(result.isExact)
    #expect(result.trials == 1_712_304)
    assertApproximately(result.winRate, 82.36, tolerance: 0.5)
    assertApproximately(result.tieRate, 0.54, tolerance: 0.5)
    assertApproximately(result.loseRate, 17.09, tolerance: 0.5)

    let total = result.winRate + result.tieRate + result.loseRate
    #expect(abs(total - 1.0) < 0.0001)
}

// MARK: - Exact enumeration on smaller board states (fast — no reason not to test these too)

@Test func exactEquityWithRiverAlreadyDealt() {
    // A complete board — only one "trial", no enumeration needed. Two pair beats a busted
    // flush draw with only ace-high.
    let hero = HoleCards(Card(rank: .ace, suit: .hearts), Card(rank: .king, suit: .hearts))!
    let villain = HoleCards(Card(rank: .nine, suit: .spades), Card(rank: .nine, suit: .diamonds))!
    let board = [
        Card(rank: .nine, suit: .clubs), Card(rank: .four, suit: .spades), Card(rank: .two, suit: .diamonds),
        Card(rank: .seven, suit: .clubs), Card(rank: .three, suit: .hearts),
    ]
    let result = Equity.headsUp(hero: hero, villain: villain, board: board)
    #expect(result.trials == 1)
    #expect(result.isExact)
    #expect(result.loseRate == 1.0, "AK-high can't beat trip nines on this board")
}

@Test func exactEquityWithFlopGivenIsFastAndCorrect() {
    // Flop given: only C(45, 2) = 990 boards — fast. Hero has flopped the nut flush draw
    // and needs to complete it or pair up; villain has an overpair.
    let hero = HoleCards(Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades))!
    let villain = HoleCards(canonical: "QQ")!
    let flop = [Card(rank: .two, suit: .spades), Card(rank: .seven, suit: .spades), Card(rank: .nine, suit: .clubs)]
    let result = Equity.headsUp(hero: hero, villain: villain, board: flop)
    #expect(result.trials == 990)
    #expect(result.isExact)
    // A flush draw + two overcards against an overpair is a real equity share, not a blowout
    // either way.
    #expect(result.winRate > 0.35 && result.winRate < 0.55)
}

@Test func exactEquityWithTurnGivenIsTrivial() {
    let hero = HoleCards(canonical: "AA")!
    let villain = HoleCards(canonical: "KK")!
    let board = [
        Card(rank: .two, suit: .hearts), Card(rank: .seven, suit: .diamonds),
        Card(rank: .nine, suit: .clubs), Card(rank: .jack, suit: .spades),
    ]
    let result = Equity.headsUp(hero: hero, villain: villain, board: board)
    #expect(result.trials == 44) // 52 - 4 hole cards - 4 board cards
    #expect(result.winRate > 0.9, "an overpair with no drawing danger on the board should be a big favorite")
}

// MARK: - Structural correctness

@Test func equityResultAlwaysSumsToOne() {
    // The headsUp case here is deliberately given a flop, not left preflop — an empty board
    // means full C(48,5) exact enumeration (minutes), and this test only needs to check
    // arithmetic, not re-prove the flagship exact test's own result.
    let flop = [Card(rank: .two, suit: .hearts), Card(rank: .seven, suit: .diamonds), Card(rank: .nine, suit: .clubs)]
    let cases: [EquityResult] = [
        Equity.headsUp(hero: HoleCards(canonical: "AA")!, villain: HoleCards(canonical: "22")!, board: flop),
        Equity.canonicalVsCanonical("AKo", "QJs", iterations: 5_000),
        Equity.monteCarlo(hero: [HoleCards(canonical: "AA")!], villain: [HoleCards(canonical: "KK")!], iterations: 5_000),
    ]
    for result in cases {
        let total = result.winRate + result.tieRate + result.loseRate
        #expect(abs(total - 1.0) < 0.0001, "win+tie+lose should sum to 1, got \(total)")
    }
}

@Test func monteCarloIsDeterministicForAFixedSeed() {
    let first = Equity.canonicalVsCanonical("AKs", "TT", iterations: 10_000, seed: 42)
    let second = Equity.canonicalVsCanonical("AKs", "TT", iterations: 10_000, seed: 42)
    #expect(first.winRate == second.winRate)
    #expect(first.tieRate == second.tieRate)
    #expect(first.trials == second.trials)
}

@Test func monteCarloDefaultSeedIsReproducibleAcrossCalls() {
    let first = Equity.canonicalVsCanonical("AA", "KK", iterations: 5_000)
    let second = Equity.canonicalVsCanonical("AA", "KK", iterations: 5_000)
    #expect(first.winRate == second.winRate)
}

@Test func monteCarloRespectsTheRequestedIterationCount() {
    let result = Equity.canonicalVsCanonical("AA", "KK", iterations: 12_345)
    #expect(result.trials == 12_345)
}

@Test func handVsHandAndHandVsSingleHandRangeAgree() {
    // A "range" containing exactly one hand should reproduce the same result as the direct
    // hand-vs-hand exact call, up to Monte Carlo sampling error — a consistency check that
    // the two code paths (headsUp's exact enumeration vs. monteCarlo's sampling) aren't
    // secretly answering different questions. Uses a flop-given board (990 boards to
    // enumerate exactly, not preflop's 1.7 million) so this stays fast — the flagship test
    // above already covers the full preflop exact-enumeration path.
    let hero = HoleCards(Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades))!
    let villain = HoleCards(canonical: "QQ")!
    let flop = [Card(rank: .two, suit: .hearts), Card(rank: .seven, suit: .diamonds), Card(rank: .nine, suit: .clubs)]
    let exact = Equity.headsUp(hero: hero, villain: villain, board: flop)
    let sampled = Equity.monteCarlo(hero: [hero], villain: [villain], board: flop, iterations: 50_000)
    assertApproximately(sampled.winRate, exact.winRate * 100, tolerance: 1.5)
}

@Test func expandCanonicalProducesTheRightComboCounts() {
    #expect(Equity.expandCanonical("AA").count == 6)
    #expect(Equity.expandCanonical("AKs").count == 4)
    #expect(Equity.expandCanonical("AKo").count == 12)
}

@Test func expandCanonicalCombosAreAllDistinctAndValid() {
    for notation in ["AA", "72o", "T9s"] {
        let combos = Equity.expandCanonical(notation)
        #expect(Set(combos).count == combos.count, "no duplicate combos for \(notation)")
        for combo in combos {
            #expect(combo.notation == notation, "\(combo.notation) should be a \(notation) combo")
        }
    }
}

@Test func expandCanonicalReturnsEmptyForMalformedNotation() {
    #expect(Equity.expandCanonical("").isEmpty)
    #expect(Equity.expandCanonical("A9x").isEmpty)
    #expect(Equity.expandCanonical("AK").isEmpty) // two different ranks with no s/o flag
}

@Test func rangeVsRangeHandlesMultiComboRangesOnBothSides() {
    // A crude "top pairs" range vs. a crude "big broadways" range — just needs to run
    // cleanly across multiple combos on both sides and produce sane probabilities.
    let heroRange = Equity.expandCanonical("AA") + Equity.expandCanonical("KK")
    let villainRange = Equity.expandCanonical("AKs") + Equity.expandCanonical("AKo")
    let result = Equity.rangeVsRange(heroRange: heroRange, villainRange: villainRange, iterations: 10_000)
    #expect(result.trials == 10_000)
    #expect(result.winRate > 0.6, "a pair range should dominate an unpaired broadway range")
}

// MARK: - Exact combo-weighted range vs. range

@Test func exactRangeVsRangeMatchesMonteCarloOnAFlopGivenBoard() {
    // Postflop, exactRangeVsRange is cheap (990 boards per combo pair) — cross-check it
    // against the already-validated Monte Carlo path on the same spot. Both should be
    // measuring the same combo-weighted quantity; exact has zero sampling error, so any
    // gap here is purely Monte Carlo noise, bounded by its own tolerance.
    let flop = [Card(rank: .two, suit: .hearts), Card(rank: .seven, suit: .diamonds), Card(rank: .nine, suit: .clubs)]
    let exact = Equity.exactCanonicalVsCanonical("AKs", "QQ", board: flop)
    let sampled = Equity.canonicalVsCanonical("AKs", "QQ", board: flop, iterations: 50_000)

    #expect(exact.isExact)
    assertApproximately(sampled.winRate, exact.winRate * 100, tolerance: 1.5)
}

@Test func exactRangeVsRangeSkipsOverlappingComboPairs() {
    // AA vs AA (contrived, but a clean edge case): most of the 6x6=36 combo pairings share a
    // card (only 4 aces exist total) and must be skipped, not silently miscounted. Uses a
    // flop-given board to stay fast — preflop would multiply an already-multi-pair
    // computation by 1,712,304 boards per pair.
    let aces = Equity.expandCanonical("AA")
    let flop = [Card(rank: .two, suit: .hearts), Card(rank: .seven, suit: .diamonds), Card(rank: .nine, suit: .clubs)]
    let result = Equity.exactRangeVsRange(heroRange: aces, villainRange: aces, board: flop)
    // Every surviving pair splits the same 4 aces between hero and villain — neither side can
    // ever make quads (all 4 aces are already spoken for), so it's a fundamentally even
    // matchup: no side should come close to dominating.
    #expect(result.trials > 0)
    #expect(result.winRate < 0.85 && result.loseRate < 0.85, "a split-aces matchup shouldn't blow out either way")
}

@Test func exactRangeVsRangeReportsTotalBoardEvaluationsAsTrials() {
    // Flop given: 990 boards per valid combo pair. AKs (4 combos) vs QQ (6 combos) has no
    // card overlap between any pair (different ranks entirely), so all 24 pairs are valid.
    let flop = [Card(rank: .two, suit: .hearts), Card(rank: .seven, suit: .diamonds), Card(rank: .nine, suit: .clubs)]
    let result = Equity.exactCanonicalVsCanonical("AKs", "QQ", board: flop)
    #expect(result.trials == 24 * 990)
}

@Test func exactRangeVsRangeHandVsHandMatchesHeadsUpDirectly() {
    // A range containing exactly one combo per side should exactly reproduce headsUp's own
    // answer — same underlying enumeration, just reached through the range-averaging path.
    let hero = HoleCards(Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades))!
    let villain = HoleCards(canonical: "QQ")!
    let flop = [Card(rank: .two, suit: .hearts), Card(rank: .seven, suit: .diamonds), Card(rank: .nine, suit: .clubs)]
    let direct = Equity.headsUp(hero: hero, villain: villain, board: flop)
    let viaRange = Equity.exactRangeVsRange(heroRange: [hero], villainRange: [villain], board: flop)
    #expect(direct.winRate == viaRange.winRate)
    #expect(direct.tieRate == viaRange.tieRate)
    #expect(direct.trials == viaRange.trials)
}
