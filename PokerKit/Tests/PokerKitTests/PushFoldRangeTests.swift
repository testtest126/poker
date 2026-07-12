import Testing
@testable import PokerKit

@Test func premiumHandAlwaysShoves() {
    let aa = HoleCards(canonical: "AA")!
    for position in Position.allCases {
        for stack: Double in [1, 5, 10, 15, 20] {
            let decision = PushFoldRange.decide(hand: aa, position: position, effectiveStackBB: stack)
            #expect(decision.action == .push, "AA should push from \(position) at \(stack)bb")
        }
    }
}

@Test func trashHandFoldsDeepAndEarly() {
    // 72o from UTG at 20bb is the textbook clear fold.
    let trash = HoleCards(canonical: "72o")!
    let decision = PushFoldRange.decide(hand: trash, position: .utg, effectiveStackBB: 20)
    #expect(decision.action == .fold)
}

@Test func knownShoveAt15bbUTG() {
    // A premium hand comfortably clears the UTG 15bb threshold (11%).
    let hand = HoleCards(canonical: "QQ")!
    let decision = PushFoldRange.decide(hand: hand, position: .utg, effectiveStackBB: 15)
    #expect(decision.action == .push)
}

@Test func wideningAsStackShortens() {
    // A hand that shoves at a deeper stack must also shove at any shorter stack,
    // from the same position — ranges only widen as the stack gets shorter.
    let hand = HoleCards(canonical: "A9s")!
    let position = Position.utg
    var lastWasPush = false
    for stack: Double in stride(from: 20, through: 1, by: -1) {
        let decision = PushFoldRange.decide(hand: hand, position: position, effectiveStackBB: stack)
        if lastWasPush {
            #expect(decision.action == .push, "Range should not tighten as stack shortens (stack \(stack))")
        }
        lastWasPush = decision.action == .push
    }
}

@Test func wideningByPosition() {
    // If a hand shoves from an earlier position, it must also shove from every
    // later position at the same stack — later positions are always >= as wide.
    let orderedPositions = Position.allCases // already earliest-to-latest
    for stack: Double in [5, 10, 15, 20] {
        for handString in ["KQo", "A9s", "88", "T9s", "A5s"] {
            let hand = HoleCards(canonical: handString)!
            var sawPush = false
            for position in orderedPositions {
                let decision = PushFoldRange.decide(hand: hand, position: position, effectiveStackBB: stack)
                if sawPush {
                    #expect(decision.action == .push, "\(handString) should still push from \(position) at \(stack)bb once it pushes from an earlier position")
                }
                sawPush = sawPush || decision.action == .push
            }
        }
    }
}

@Test func shovePercentageInterpolatesBetweenBreakpoints() {
    // 10bb and 12bb are both explicit breakpoints for UTG (18% and 15%); 11bb should
    // land between them.
    let at10 = PushFoldRange.shovePercentage(position: .utg, effectiveStackBB: 10)
    let at11 = PushFoldRange.shovePercentage(position: .utg, effectiveStackBB: 11)
    let at12 = PushFoldRange.shovePercentage(position: .utg, effectiveStackBB: 12)
    #expect(at12 < at11)
    #expect(at11 < at10)
}

@Test func shovePercentageClampsOutsideDefinedRange() {
    let below = PushFoldRange.shovePercentage(position: .button, effectiveStackBB: 0.2)
    let at1 = PushFoldRange.shovePercentage(position: .button, effectiveStackBB: 1)
    #expect(below == at1)

    let above = PushFoldRange.shovePercentage(position: .button, effectiveStackBB: 40)
    let at20 = PushFoldRange.shovePercentage(position: .button, effectiveStackBB: 20)
    #expect(above == at20)
}

@Test func rankedCanonicalScoresCoverAll169Hands() {
    #expect(PushFoldRange.rankedCanonicalScores.count == 169)
}

@Test func scoreThresholdIsMonotonicWithPercentage() {
    let narrow = PushFoldRange.scoreThreshold(forPercentage: 10)
    let wide = PushFoldRange.scoreThreshold(forPercentage: 50)
    #expect(wide <= narrow)
}

@Test func buttonIsWiderThanUTGAtSameStack() {
    let utgPct = PushFoldRange.shovePercentage(position: .utg, effectiveStackBB: 10)
    let btnPct = PushFoldRange.shovePercentage(position: .button, effectiveStackBB: 10)
    #expect(btnPct > utgPct)
}

@Test func pushFoldSpotProducesConsistentDecision() {
    let spot = PushFoldSpot(hand: HoleCards(canonical: "AA")!, position: .utg, effectiveStackBB: 10)
    #expect(spot.decision.action == .push)
}
