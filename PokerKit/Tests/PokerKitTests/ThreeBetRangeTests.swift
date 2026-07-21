import Testing
@testable import PokerKit

@Test func threeBetInvalidPositionPairingsReturnNil() {
    // UTG acts first — it can never be 3-betting anyone's open.
    for opener in Position.allCases {
        #expect(ThreeBetRange.totalThreeBetPercentage(defender: .utg, opener: opener, effectiveStackBB: 100) == nil)
    }
    // A position can't 3-bet its own open.
    #expect(ThreeBetRange.totalThreeBetPercentage(defender: .cutoff, opener: .cutoff, effectiveStackBB: 100) == nil)
    // Nor an open from someone who acts after it.
    #expect(ThreeBetRange.totalThreeBetPercentage(defender: .hijack, opener: .button, effectiveStackBB: 100) == nil)

    #expect(ThreeBetRange.decide(hand: HoleCards(canonical: "AA")!, defender: .utg, opener: .button, effectiveStackBB: 100) == nil)
}

@Test func bigBlindThreeBetVsButtonMatchesTheSourcedAnchor() {
    // Sourced: BB 3-bets ~12-14% of hands vs a BTN open at 100bb (this project's anchor is
    // the midpoint, 13%) — see RANGES.md. At the anchor pairing itself, the ratio scaling
    // is exactly 1, so this should reproduce the raw anchor number.
    let percentage = ThreeBetRange.totalThreeBetPercentage(defender: .bigBlind, opener: .button, effectiveStackBB: 100)
    #expect(percentage == 13)
}

@Test func premiumHandAlways3BetsForValue() {
    let aa = HoleCards(canonical: "AA")!
    for opener in Position.allCases {
        for defender in DefendingPosition.allCases where defender.actionOrderIndex > opener.actionOrderIndex {
            let decision = ThreeBetRange.decide(hand: aa, defender: defender, opener: opener, effectiveStackBB: 100)
            #expect(decision?.action == .threeBetValue, "AA should 3-bet for value vs \(opener) from \(defender)")
        }
    }
}

@Test func trashHandFolds() {
    let trash = HoleCards(canonical: "72o")!
    let decision = ThreeBetRange.decide(hand: trash, defender: .bigBlind, opener: .utg, effectiveStackBB: 100)!
    #expect(decision.action == .fold)
}

@Test func threeBetValueWidensAgainstALaterOpenerAtTheSameStack() {
    let vsUTG = ThreeBetRange.totalThreeBetPercentage(defender: .bigBlind, opener: .utg, effectiveStackBB: 100)!
    let vsButton = ThreeBetRange.totalThreeBetPercentage(defender: .bigBlind, opener: .button, effectiveStackBB: 100)!
    #expect(vsUTG < vsButton, "3-bet range should be tighter against an earlier (stronger) opening range")
}

@Test func bluffCombosAre3BetBluffsWhenStackIsDeepEnough() {
    // Suited wheel aces are designated blocker bluffs whenever the spot is valid and the
    // stack is deep enough (>= 20bb) — regardless of whether they'd independently clear the
    // value threshold (the whole point of a polarized range: these are *not* value hands).
    for combo in ThreeBetRange.bluffCombos {
        let hand = HoleCards(canonical: combo)!
        let decision = ThreeBetRange.decide(hand: hand, defender: .bigBlind, opener: .button, effectiveStackBB: 100)!
        #expect(decision.action == .threeBetBluff || decision.action == .threeBetValue, "\(combo) should be in the 3-bet range (bluff or value) at 100bb")
        #expect(decision.isBluffCombo)
    }
}

@Test func bluffCombosDoNotApplyBelowTwentyBB() {
    let hand = HoleCards(canonical: "A5s")!
    let decision = ThreeBetRange.decide(hand: hand, defender: .bigBlind, opener: .button, effectiveStackBB: 15)!
    #expect(!decision.isBluffCombo, "3-bet bluffing shouldn't apply at short-stack push/fold depths")
}

@Test func threeBetPercentageNeverExceedsTotalDefense() {
    for opener in Position.allCases {
        for defender in DefendingPosition.allCases where defender.actionOrderIndex > opener.actionOrderIndex {
            for stack: Double in [20, 40, 100] {
                let decision = ThreeBetRange.decide(hand: HoleCards(canonical: "AKs")!, defender: defender, opener: opener, effectiveStackBB: stack)!
                #expect(decision.threeBetPercentage <= decision.totalDefensePercentage)
            }
        }
    }
}

@Test func valueThresholdIsAtLeastAsTightAsCallThreshold() {
    for opener in Position.allCases {
        for defender in DefendingPosition.allCases where defender.actionOrderIndex > opener.actionOrderIndex {
            let decision = ThreeBetRange.decide(hand: HoleCards(canonical: "AKs")!, defender: defender, opener: opener, effectiveStackBB: 100)!
            #expect(decision.valueThreshold >= decision.callThreshold)
        }
    }
}

@Test func reasoningMentionsTheRelevantThreshold() {
    let value = ThreeBetRange.decide(hand: HoleCards(canonical: "AA")!, defender: .bigBlind, opener: .utg, effectiveStackBB: 100)!
    #expect(value.reasoning.contains("3-bet-value threshold"))

    let bluff = ThreeBetRange.decide(hand: HoleCards(canonical: "A4s")!, defender: .bigBlind, opener: .button, effectiveStackBB: 100)!
    if bluff.action == .threeBetBluff {
        #expect(bluff.reasoning.contains("blocker-bluff combo"))
    }

    let fold = ThreeBetRange.decide(hand: HoleCards(canonical: "72o")!, defender: .bigBlind, opener: .utg, effectiveStackBB: 100)!
    #expect(fold.reasoning.contains("calling threshold"))
}
