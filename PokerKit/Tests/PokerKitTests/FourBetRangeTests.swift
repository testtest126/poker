import Testing
@testable import PokerKit

@Test func fourBetInvalidPositionPairingsReturnNil() {
    // UTG opened — nobody 3-bets it from a position that acts before UTG (impossible), and
    // UTG can't have "3-bet itself."
    for opener in Position.allCases {
        #expect(FourBetRange.totalContinuePercentage(opener: opener, threeBettor: .utg, effectiveStackBB: 100) == nil)
    }
    #expect(FourBetRange.totalContinuePercentage(opener: .cutoff, threeBettor: .cutoff, effectiveStackBB: 100) == nil)

    #expect(FourBetRange.decide(hand: HoleCards(canonical: "AA")!, opener: .button, threeBettor: .utg, effectiveStackBB: 100) == nil)
}

@Test func cutoffVsButtonThreeBetMatchesTheSourcedAnchor() {
    // Sourced: a cutoff open facing a button 3-bet continues 67% (50% call + 17% four-bet),
    // assumed ~100bb — the exact anchor pairing, so the ratio scaling is 1 and this should
    // reproduce the raw anchor numbers.
    let totalContinue = FourBetRange.totalContinuePercentage(opener: .cutoff, threeBettor: .button, effectiveStackBB: 100)!
    #expect(abs(totalContinue - 67) < 0.01)

    let decision = FourBetRange.decide(hand: HoleCards(canonical: "AA")!, opener: .cutoff, threeBettor: .button, effectiveStackBB: 100)!
    let expectedFourBetPercentage = 67.0 * (17.0 / 67.0)
    #expect(abs(decision.fourBetPercentage - expectedFourBetPercentage) < 0.01)
}

@Test func premiumHandAlways4BetsForValue() {
    let aa = HoleCards(canonical: "AA")!
    for opener in Position.allCases {
        for threeBettor in DefendingPosition.allCases where threeBettor.actionOrderIndex > opener.actionOrderIndex {
            let decision = FourBetRange.decide(hand: aa, opener: opener, threeBettor: threeBettor, effectiveStackBB: 100)
            #expect(decision?.action == .fourBetValue, "AA should 4-bet for value vs a 3-bet from \(threeBettor) after opening \(opener)")
        }
    }
}

@Test func fourBetTrashHandFolds() {
    let trash = HoleCards(canonical: "72o")!
    let decision = FourBetRange.decide(hand: trash, opener: .utg, threeBettor: .bigBlind, effectiveStackBB: 100)!
    #expect(decision.action == .fold)
}

@Test func totalContinueWidensAgainstANarrower3Bet() {
    // ThreeBetRange itself predicts a tighter 3-bet range against an earlier opener (see
    // ThreeBetRangeTests) — a tighter, more polarized-toward-premium 3-bet should make the
    // original opener continue *narrower*, not wider, since the 3-bettor's range is
    // stronger on average.
    let vsUTGOpen = FourBetRange.totalContinuePercentage(opener: .utg, threeBettor: .bigBlind, effectiveStackBB: 100)!
    let vsButtonOpen = FourBetRange.totalContinuePercentage(opener: .button, threeBettor: .bigBlind, effectiveStackBB: 100)!
    #expect(vsUTGOpen < vsButtonOpen, "Facing a 3-bet should be scarier (tighter continue) after opening from UTG than from the button")
}

@Test func bluffComboRequiresHandWouldHaveBeenOpened() {
    // Every designated bluff combo that's flagged as a bluff must, by construction, also be
    // a hand `OpeningRange` would have opened from that position/stack — you can't
    // 4-bet-bluff with a hand you'd have folded preflop.
    for combo in ThreeBetRange.bluffCombos {
        let hand = HoleCards(canonical: combo)!
        for opener in Position.allCases {
            for threeBettor in DefendingPosition.allCases where threeBettor.actionOrderIndex > opener.actionOrderIndex {
                guard let decision = FourBetRange.decide(hand: hand, opener: opener, threeBettor: threeBettor, effectiveStackBB: 100) else { continue }
                if decision.isBluffCombo {
                    let wouldHaveOpened = OpeningRange.decide(hand: hand, position: opener, effectiveStackBB: 100).action == .raise
                    #expect(wouldHaveOpened, "\(combo) flagged as a 4-bet bluff from \(opener) but wouldn't have been opened there")
                }
            }
        }
    }
}

@Test func bluffCombosDoNotApplyBelowFortyBB() {
    let hand = HoleCards(canonical: "A5s")!
    let decision = FourBetRange.decide(hand: hand, opener: .button, threeBettor: .bigBlind, effectiveStackBB: 25)!
    #expect(!decision.isBluffCombo, "4-bet bluffing shouldn't apply below the stack depth where a 4-bet is meaningfully different from a shove")
}

@Test func fourBetValueThresholdIsAtLeastAsTightAsCallThreshold() {
    for opener in Position.allCases {
        for threeBettor in DefendingPosition.allCases where threeBettor.actionOrderIndex > opener.actionOrderIndex {
            let decision = FourBetRange.decide(hand: HoleCards(canonical: "AKs")!, opener: opener, threeBettor: threeBettor, effectiveStackBB: 100)!
            #expect(decision.valueThreshold >= decision.callThreshold)
        }
    }
}

@Test func fourBetReasoningMentionsTheRelevantThreshold() {
    let value = FourBetRange.decide(hand: HoleCards(canonical: "AA")!, opener: .utg, threeBettor: .bigBlind, effectiveStackBB: 100)!
    #expect(value.reasoning.contains("4-bet-value threshold"))

    let fold = FourBetRange.decide(hand: HoleCards(canonical: "72o")!, opener: .utg, threeBettor: .bigBlind, effectiveStackBB: 100)!
    #expect(fold.reasoning.contains("calling threshold"))
}
