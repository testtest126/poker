import Testing
@testable import PokerKit

@Test func premiumHandAlwaysOpens() {
    let aa = HoleCards(canonical: "AA")!
    for position in Position.allCases {
        for stack: Double in [20, 40, 60, 100] {
            let decision = OpeningRange.decide(hand: aa, position: position, effectiveStackBB: stack)
            #expect(decision.action == .raise, "AA should open from \(position) at \(stack)bb")
        }
    }
}

@Test func openingTrashHandFoldsDeepAndEarly() {
    // 72o from UTG at 100bb is the textbook clear fold — nowhere near an opening hand.
    let trash = HoleCards(canonical: "72o")!
    let decision = OpeningRange.decide(hand: trash, position: .utg, effectiveStackBB: 100)
    #expect(decision.action == .fold)
}

@Test func openingWidensAsStackShortens() {
    // A hand that opens at a deeper stack must also open at any shorter stack (down to
    // the 20bb floor of this model), from the same position — ranges only widen as the
    // stack gets shorter, same invariant as PushFoldRange.
    let hand = HoleCards(canonical: "A9s")!
    let position = Position.utg
    var lastWasOpen = false
    for stack: Double in stride(from: 100, through: 20, by: -5) {
        let decision = OpeningRange.decide(hand: hand, position: position, effectiveStackBB: stack)
        if lastWasOpen {
            #expect(decision.action == .raise, "Range should not tighten as stack shortens (stack \(stack))")
        }
        lastWasOpen = decision.action == .raise
    }
}

@Test func openingWidensByPosition() {
    // If a hand opens from an earlier position, it must also open from every later
    // position at the same stack — later positions are always >= as wide.
    let orderedPositions = Position.allCases // already earliest-to-latest
    for stack: Double in [20, 40, 60, 100] {
        for handString in ["KQo", "A9s", "88", "T9s", "A5s"] {
            let hand = HoleCards(canonical: handString)!
            var sawOpen = false
            for position in orderedPositions {
                let decision = OpeningRange.decide(hand: hand, position: position, effectiveStackBB: stack)
                if sawOpen {
                    #expect(decision.action == .raise, "\(handString) should still open from \(position) at \(stack)bb once it opens from an earlier position")
                }
                sawOpen = sawOpen || decision.action == .raise
            }
        }
    }
}

@Test func openPercentageInterpolatesBetweenBreakpoints() {
    // 20bb and 40bb are both explicit breakpoints for UTG (16% and 13%); 30bb should
    // land strictly between them.
    let at20 = OpeningRange.openPercentage(position: .utg, effectiveStackBB: 20)
    let at30 = OpeningRange.openPercentage(position: .utg, effectiveStackBB: 30)
    let at40 = OpeningRange.openPercentage(position: .utg, effectiveStackBB: 40)
    #expect(at40 < at30)
    #expect(at30 < at20)
}

@Test func openPercentageClampsOutsideDefinedRange() {
    let below = OpeningRange.openPercentage(position: .button, effectiveStackBB: 5)
    let at20 = OpeningRange.openPercentage(position: .button, effectiveStackBB: 20)
    #expect(below == at20)

    let above = OpeningRange.openPercentage(position: .button, effectiveStackBB: 200)
    let at100 = OpeningRange.openPercentage(position: .button, effectiveStackBB: 100)
    #expect(above == at100)
}

@Test func openingButtonIsWiderThanUTGAtSameStack() {
    let utgPct = OpeningRange.openPercentage(position: .utg, effectiveStackBB: 100)
    let btnPct = OpeningRange.openPercentage(position: .button, effectiveStackBB: 100)
    #expect(btnPct > utgPct)
}

@Test func smallBlindIsWiderThanButtonAtSameStack() {
    // Matches the cited source's qualitative shape: SB opens wider than BTN since SB is
    // only getting through one player (BB), even though the absolute SB number here is
    // deliberately tightened below the source's raw figure — see RANGES.md.
    for stack: Double in [20, 40, 100] {
        let btnPct = OpeningRange.openPercentage(position: .button, effectiveStackBB: stack)
        let sbPct = OpeningRange.openPercentage(position: .smallBlind, effectiveStackBB: stack)
        #expect(sbPct > btnPct, "SB should open wider than BTN at \(stack)bb")
    }
}

@Test func reasoningMentionsRaiseOrFold() {
    let decision = OpeningRange.decide(hand: HoleCards(canonical: "AA")!, position: .utg, effectiveStackBB: 100)
    #expect(decision.reasoning.contains("open-raise threshold"))
}
