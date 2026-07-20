import Testing
@testable import PokerKit

// MARK: - bountyBB conversion

@Test func bountyBBMultipliesFractionByStartingStack() {
    #expect(BountyEquity.bountyBB(fractionOfStartingStack: 0.33, startingStackBB: 100) == 33)
}

@Test func bountyBBClampsNegativeInputsToZero() {
    #expect(BountyEquity.bountyBB(fractionOfStartingStack: -0.5, startingStackBB: 100) == 0)
    #expect(BountyEquity.bountyBB(fractionOfStartingStack: 0.5, startingStackBB: -100) == 0)
}

// MARK: - thresholdMultiplier

@Test func thresholdMultiplierIsOneWithNoBounty() {
    #expect(BountyEquity.thresholdMultiplier(effectiveStackBB: 10, bountyBB: 0, heroCoversVillain: true) == 1)
}

@Test func thresholdMultiplierIsOneWhenHeroDoesNotCoverVillain() {
    #expect(BountyEquity.thresholdMultiplier(effectiveStackBB: 10, bountyBB: 20, heroCoversVillain: false) == 1)
}

@Test func thresholdMultiplierMatchesThePotOverPotPlusBountyFormula() {
    // 10bb effective -> pot approximated as 2x = 20bb. A 10bb bounty: 20 / (20 + 10) = 2/3.
    let multiplier = BountyEquity.thresholdMultiplier(effectiveStackBB: 10, bountyBB: 10, heroCoversVillain: true)
    #expect(abs(multiplier - (20.0 / 30.0)) < 0.0001)
}

@Test func thresholdMultiplierShrinksAsBountyGrows() {
    let small = BountyEquity.thresholdMultiplier(effectiveStackBB: 10, bountyBB: 5, heroCoversVillain: true)
    let large = BountyEquity.thresholdMultiplier(effectiveStackBB: 10, bountyBB: 50, heroCoversVillain: true)
    #expect(large < small)
    #expect(small < 1)
}

// MARK: - widenedPercentage

@Test func widenedPercentageIsExactNoOpWithZeroBounty() {
    for base: Double in [5, 22, 50, 90] {
        let widened = BountyEquity.widenedPercentage(baseShovePercentage: base, effectiveStackBB: 10, bountyBB: 0, heroCoversVillain: true)
        #expect(widened == base)
    }
}

@Test func widenedPercentageIsExactNoOpWhenHeroDoesNotCoverVillain() {
    let widened = BountyEquity.widenedPercentage(baseShovePercentage: 22, effectiveStackBB: 10, bountyBB: 50, heroCoversVillain: false)
    #expect(widened == 22)
}

@Test func widenedPercentageIsMonotonicallyWiderAsBountyGrows() {
    var last = BountyEquity.widenedPercentage(baseShovePercentage: 20, effectiveStackBB: 10, bountyBB: 0, heroCoversVillain: true)
    for bounty: Double in [1, 5, 10, 20, 50, 100, 500] {
        let widened = BountyEquity.widenedPercentage(baseShovePercentage: 20, effectiveStackBB: 10, bountyBB: bounty, heroCoversVillain: true)
        #expect(widened >= last, "Widened percentage should never shrink as the bounty grows (bounty \(bounty))")
        last = widened
    }
}

@Test func widenedPercentageClampsAtOneHundred() {
    let widened = BountyEquity.widenedPercentage(baseShovePercentage: 90, effectiveStackBB: 5, bountyBB: 1000, heroCoversVillain: true)
    #expect(widened == 100)
}

@Test func widenedPercentageWidensMoreAtShorterStacksForTheSameFlatBounty() {
    // The same 20bb bounty is a bigger fraction of a smaller approximated pot at a shorter
    // stack, so the relative widening should be larger.
    let shortStack = BountyEquity.widenedPercentage(baseShovePercentage: 20, effectiveStackBB: 5, bountyBB: 20, heroCoversVillain: true)
    let deepStack = BountyEquity.widenedPercentage(baseShovePercentage: 20, effectiveStackBB: 20, bountyBB: 20, heroCoversVillain: true)
    #expect(shortStack > deepStack)
}

// MARK: - decide

@Test func decideWithZeroBountyReproducesPushFoldRangeExactly() {
    for position in Position.allCases {
        for stack: Double in [1, 5, 10, 15, 20] {
            for handString in ["AA", "72o", "A9s", "KQo", "T9s"] {
                let hand = HoleCards(canonical: handString)!
                let base = PushFoldRange.decide(hand: hand, position: position, effectiveStackBB: stack)
                let withZeroBounty = BountyEquity.decide(
                    hand: hand, position: position, effectiveStackBB: stack, bountyBB: 0, heroCoversVillain: true
                )
                #expect(withZeroBounty.action == base.action)
                #expect(withZeroBounty.handScore == base.handScore)
                #expect(withZeroBounty.adjustedScoreThreshold == base.scoreThreshold)
                #expect(withZeroBounty.adjustedShovePercentage == base.shovePercentage)
                #expect(withZeroBounty.bountyChangedTheRange == false)
            }
        }
    }
}

@Test func decideWithBountyButHeroNotCoveringReproducesBaseDecision() {
    let hand = HoleCards(canonical: "A9s")!
    let base = PushFoldRange.decide(hand: hand, position: .utg, effectiveStackBB: 10)
    let notCovering = BountyEquity.decide(
        hand: hand, position: .utg, effectiveStackBB: 10, bountyBB: 100, heroCoversVillain: false
    )
    #expect(notCovering.action == base.action)
    #expect(notCovering.adjustedShovePercentage == base.shovePercentage)
    #expect(notCovering.bountyChangedTheRange == false)
}

@Test func hugeBountyWidensEvenTheWorstHandIntoTheShoveRange() {
    // 72o is the textbook worst hand — a large enough bounty should still be able to push
    // its (clamped-at-100%) shove percentage all the way to "shove everything."
    let trash = HoleCards(canonical: "72o")!
    let decision = BountyEquity.decide(
        hand: trash, position: .utg, effectiveStackBB: 20, bountyBB: 100_000, heroCoversVillain: true
    )
    #expect(decision.adjustedShovePercentage == 100)
    #expect(decision.action == .push)
}

@Test func moderateBountyCanFlipABorderlineHandFromFoldToPush() {
    // Find a hand that's a clear fold with no bounty at this spot but clears the (widened)
    // threshold once a meaningful bounty is added.
    let position = Position.utg
    let stack = 15.0
    let borderlineHand = HoleCards(canonical: "A5s")!

    let withoutBounty = BountyEquity.decide(
        hand: borderlineHand, position: position, effectiveStackBB: stack, bountyBB: 0, heroCoversVillain: true
    )
    let withBounty = BountyEquity.decide(
        hand: borderlineHand, position: position, effectiveStackBB: stack, bountyBB: 30, heroCoversVillain: true
    )

    #expect(withoutBounty.action == .fold, "Test setup assumption: this hand should be a clear fold with no bounty")
    #expect(withBounty.action == .push, "A large-enough bounty should flip a borderline fold into a push")
    #expect(withBounty.bountyChangedTheRange)
}

@Test func decideNeverNarrowsTheRangeRelativeToBase() {
    // Across a spread of spots, the bounty-adjusted percentage should never be less than
    // the base percentage — the overlay only ever widens.
    for position in Position.allCases {
        for stack: Double in [1, 5, 10, 20] {
            for bounty: Double in [0, 1, 10, 50, 200] {
                let base = PushFoldRange.shovePercentage(position: position, effectiveStackBB: stack)
                let decision = BountyEquity.decide(
                    hand: HoleCards(canonical: "T9s")!, position: position, effectiveStackBB: stack,
                    bountyBB: bounty, heroCoversVillain: true
                )
                #expect(decision.adjustedShovePercentage >= base)
            }
        }
    }
}

// MARK: - reasoning

@Test func reasoningMentionsNoBountyWhenBountyIsZero() {
    let decision = BountyEquity.decide(
        hand: HoleCards(canonical: "AA")!, position: .utg, effectiveStackBB: 10, bountyBB: 0, heroCoversVillain: true
    )
    #expect(decision.reasoning.contains("No bounty entered"))
}

@Test func reasoningMentionsNotCollectibleWhenHeroDoesNotCoverVillain() {
    let decision = BountyEquity.decide(
        hand: HoleCards(canonical: "AA")!, position: .utg, effectiveStackBB: 10, bountyBB: 50, heroCoversVillain: false
    )
    #expect(decision.reasoning.contains("isn't collectible"))
}

@Test func reasoningMentionsWideningWhenBountyApplies() {
    let decision = BountyEquity.decide(
        hand: HoleCards(canonical: "AA")!, position: .utg, effectiveStackBB: 10, bountyBB: 50, heroCoversVillain: true
    )
    #expect(decision.reasoning.contains("bounty"))
    #expect(decision.reasoning.contains("widens"))
}
