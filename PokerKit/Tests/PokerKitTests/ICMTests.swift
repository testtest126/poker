import Testing
@testable import PokerKit

@Test func equalStacksSplitEquallyRegardlessOfPlayerCount() {
    for n in 2...6 {
        let stacks = Array(repeating: 1000.0, count: n)
        let payouts = [500.0, 300.0, 200.0, 100.0, 50.0, 25.0]
        let equities = ICM.equities(stacks: stacks, payouts: payouts)
        let expectedEach = payouts.prefix(min(payouts.count, n)).reduce(0, +) / Double(n)
        for equity in equities {
            #expect(abs(equity - expectedEach) < 1e-9)
        }
    }
}

@Test func twoPlayerEquityMatchesTheExactClosedForm() {
    // With exactly 2 players left, ICM collapses to a formula verifiable by hand:
    // seat equity = (ownStack / totalStack) * p1 + (otherStack / totalStack) * p2.
    let a = 6000.0
    let b = 4000.0
    let payouts = [100.0, 50.0]
    let equities = ICM.equities(stacks: [a, b], payouts: payouts)

    let expectedA = (a / (a + b)) * payouts[0] + (b / (a + b)) * payouts[1]
    let expectedB = (b / (a + b)) * payouts[0] + (a / (a + b)) * payouts[1]
    #expect(abs(equities[0] - expectedA) < 1e-9)
    #expect(abs(equities[1] - expectedB) < 1e-9)
    #expect(abs((equities[0] + equities[1]) - (payouts[0] + payouts[1])) < 1e-9)
}

@Test func threeHandedWorkedExampleMatchesWikipediasPublishedICMArticle() {
    // Published worked example, Wikipedia's "Independent Chip Model" article (see
    // ai-docs/ICM.md for the citation and the full by-hand re-derivation): stacks A/B/C =
    // 50%/30%/20% of the chips in play, payouts 70 (1st) / 30 (2nd) / 0 (3rd, unpaid).
    // Published (rounded) figures: A ≈ $45, B ≈ $32, C ≈ $22 (sums to ~$100 less rounding).
    let stacks = [50.0, 30.0, 20.0]
    let payouts = [70.0, 30.0]
    let equities = ICM.equities(stacks: stacks, payouts: payouts)

    // The source itself only publishes these to whole dollars with an explicit "≈" — its own
    // rounding, not this project's precision, sets the tolerance here (loosest for C: the
    // source's $22 is actually $22.57 rounded down, off by $0.57 from the true value). The
    // exact-fraction assertions below are the real precision check.
    #expect(abs(equities[0] - 45) < 0.5)
    #expect(abs(equities[1] - 32) < 0.5)
    #expect(abs(equities[2] - 22) < 0.6)

    // Tight tolerance against the exact fractions this project independently re-derived by
    // hand from the same recursive definition (see ai-docs/ICM.md) — 1265/28, 129/4, 158/7.
    #expect(abs(equities[0] - 1265.0 / 28.0) < 1e-9)
    #expect(abs(equities[1] - 129.0 / 4.0) < 1e-9)
    #expect(abs(equities[2] - 158.0 / 7.0) < 1e-9)
    #expect(abs(equities.reduce(0, +) - 100) < 1e-9)
}

@Test func threeHandedWorkedExampleWithThreePaidPlacesMatchesHandDerivedFractions() {
    // A second worked example, hand-derived by this project (not third-party-sourced — see
    // ai-docs/ICM.md) to exercise the full 3-place recursion (the Wikipedia example above
    // only pays 2 places, so it never exercises the "3rd place" branch of the recursion).
    // Same 50/30/20 stack split, standard 50/30/20 payout of a $1000 pool.
    let stacks = [5000.0, 3000.0, 2000.0]
    let payouts = [500.0, 300.0, 200.0]
    let equities = ICM.equities(stacks: stacks, payouts: payouts)

    #expect(abs(equities[0] - 5375.0 / 14.0) < 1e-9)
    #expect(abs(equities[1] - 655.0 / 2.0) < 1e-9)
    #expect(abs(equities[2] - 2020.0 / 7.0) < 1e-9)
    #expect(abs(equities.reduce(0, +) - 1000) < 1e-9)
}

@Test func chipLeaderIsWorthLessPerChipThanTheShortStackTheICMTax() {
    let stacks = [5000.0, 3000.0, 2000.0]
    let payouts = [500.0, 300.0, 200.0]
    let equities = ICM.equities(stacks: stacks, payouts: payouts)

    let chipLeaderPerChip = equities[0] / stacks[0]
    let shortStackPerChip = equities[2] / stacks[2]
    #expect(chipLeaderPerChip < shortStackPerChip, "A top-heavy payout structure should make the chip leader's marginal chip worth less than the short stack's")
}

@Test func totalEquityAlwaysEqualsTotalPrizePoolAcrossVariedFields() {
    let cases: [(stacks: [Double], payouts: [Double])] = [
        ([100, 100, 100, 100], [40, 30, 20, 10]),
        ([1, 2, 3, 4, 5], [50, 30, 20]),
        ([9000, 500, 300, 200], [60, 25, 15]),
        ([17, 33], [70, 30]),
    ]
    for testCase in cases {
        let equities = ICM.equities(stacks: testCase.stacks, payouts: testCase.payouts)
        let expectedTotal = testCase.payouts.prefix(testCase.stacks.count).reduce(0, +)
        #expect(abs(equities.reduce(0, +) - expectedTotal) < 1e-6)
    }
}

@Test func singlePlayerGetsFirstPlacePayoutWithCertainty() {
    let equities = ICM.equities(stacks: [12345], payouts: [500, 300, 200])
    #expect(abs(equities[0] - 500) < 1e-9)
}

// MARK: - ICMRiskPremium

@Test func chipEVBreakevenIsFiftyPercentForEqualStacksHeadsUp() {
    let assessment = ICMRiskPremium.assess(heroStack: 1000, villainStack: 1000, otherStacks: [], payouts: [100])
    #expect(abs(assessment.chipEVRequiredEquity - 0.5) < 1e-9)
}

@Test func chipEVBreakevenFavorsTheShorterStack() {
    // A shorter stack risks less to win relatively more (a bigger fractional double-up), so
    // it needs less than 50% equity to profitably call off its whole stack — and the larger
    // stack, symmetrically, needs more than 50%.
    let shortCalling = ICMRiskPremium.assess(heroStack: 1000, villainStack: 4000, otherStacks: [], payouts: [100])
    #expect(shortCalling.chipEVRequiredEquity < 0.5)

    let bigCalling = ICMRiskPremium.assess(heroStack: 4000, villainStack: 1000, otherStacks: [], payouts: [100])
    #expect(bigCalling.chipEVRequiredEquity > 0.5)
}

@Test func icmRequiredEquityExceedsChipEVNearABubbleWithOtherShortStacksAlive() {
    // The textbook ICM-pressure spot: hero and villain are both comfortably above a couple
    // of much shorter stacks who are current bubble/min-cash candidates. Busting hero
    // shouldn't just cost chips — it should cost hero their shot at the stacks who are
    // likely to bust *before* hero if hero survives. That should push the ICM-required
    // calling equity above the flat chip-EV number.
    let assessment = ICMRiskPremium.assess(
        heroStack: 5000, villainStack: 5000, otherStacks: [1000, 1000], payouts: [50, 30, 15, 5]
    )
    #expect(assessment.icmRequiredEquity > assessment.chipEVRequiredEquity)
    #expect(assessment.riskPremium > 0)
}

@Test func icmRequiredEquityIsUnaffectedWhenNothingIsAtStakeBeyondTheConfrontation() {
    // Heads-up for the whole prize pool (winner takes all-remaining), no other stacks, no
    // payout jump to protect against — ICM pressure should collapse back to the chip-EV
    // number (no bubble to protect a min-cash on when there's only one payout left and only
    // two players).
    let assessment = ICMRiskPremium.assess(heroStack: 3000, villainStack: 7000, otherStacks: [], payouts: [100])
    #expect(abs(assessment.icmRequiredEquity - assessment.chipEVRequiredEquity) < 1e-9)
}

@Test func winAndLoseEquityBracketTheFoldEquity() {
    let assessment = ICMRiskPremium.assess(
        heroStack: 4000, villainStack: 2000, otherStacks: [3000, 1000], payouts: [50, 30, 20]
    )
    #expect(assessment.loseEquity < assessment.foldEquity)
    #expect(assessment.foldEquity < assessment.winEquity)
}
