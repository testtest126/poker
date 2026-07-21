import Testing
@testable import PokerKit

// MARK: - Facing a shove

@Test func premiumHandAlwaysCallsAShove() {
    let aa = HoleCards(canonical: "AA")!
    for shover in Position.allCases {
        for caller in DefendingPosition.allCases where caller.actionOrderIndex > shover.actionOrderIndex {
            for stack: Double in [1, 5, 10, 15, 20] {
                let decision = CallingRange.decideVsShove(hand: aa, caller: caller, shover: shover, effectiveStackBB: stack)
                #expect(decision?.action == .call, "AA should call \(shover)'s shove from \(caller) at \(stack)bb")
            }
        }
    }
}

@Test func trashHandFoldsToAShoveDeepAndEarly() {
    // 72o facing a UTG shove at 20bb (the widest the model goes) is a clear fold for any caller.
    let trash = HoleCards(canonical: "72o")!
    for caller in DefendingPosition.allCases where caller.actionOrderIndex > Position.utg.actionOrderIndex {
        let decision = CallingRange.decideVsShove(hand: trash, caller: caller, shover: .utg, effectiveStackBB: 20)
        #expect(decision?.action == .fold, "72o should fold to a UTG shove from \(caller) at 20bb")
    }
}

@Test func vsShoveInvalidPositionPairingsReturnNil() {
    // UTG acts first at an unopened table — it can never be facing anyone else's shove.
    for shover in Position.allCases {
        #expect(CallingRange.callPercentage(caller: .utg, shover: shover, effectiveStackBB: 10) == nil)
        #expect(CallingRange.decideVsShove(hand: HoleCards(canonical: "AA")!, caller: .utg, shover: shover, effectiveStackBB: 10) == nil)
    }
    // A position can't face its own shove.
    #expect(CallingRange.callPercentage(caller: .smallBlind, shover: .smallBlind, effectiveStackBB: 10) == nil)
    // Nor a shove from someone who acts after it.
    #expect(CallingRange.callPercentage(caller: .hijack, shover: .button, effectiveStackBB: 10) == nil)
}

@Test func bigBlindCanFaceAShoveFromEveryPosition() {
    // The big blind always closes the action, so it's never an invalid pairing.
    for shover in Position.allCases {
        #expect(CallingRange.callPercentage(caller: .bigBlind, shover: shover, effectiveStackBB: 10) != nil)
    }
}

@Test func callWidensAsStackShortens() {
    // Same invariant as PushFoldRange/OpeningRange: once a hand calls at a given stack, it
    // must also call at every shorter stack from the same position pairing.
    let hand = HoleCards(canonical: "A9s")!
    var lastWasCall = false
    for stack: Double in stride(from: 20, through: 1, by: -1) {
        let decision = CallingRange.decideVsShove(hand: hand, caller: .bigBlind, shover: .utg, effectiveStackBB: stack)!
        if lastWasCall {
            #expect(decision.action == .call, "Calling range should not tighten as stack shortens (stack \(stack))")
        }
        lastWasCall = decision.action == .call
    }
}

@Test func callIsTighterAgainstAnEarlierShoverAtTheSameStack() {
    // An earlier shover's range is stronger (PushFoldRange itself shoves tighter from UTG
    // than SB), so a rational caller needs more to call it.
    let utgCallPct = CallingRange.callPercentage(caller: .bigBlind, shover: .utg, effectiveStackBB: 10)!
    let sbCallPct = CallingRange.callPercentage(caller: .bigBlind, shover: .smallBlind, effectiveStackBB: 10)!
    #expect(utgCallPct < sbCallPct)
}

@Test func bigBlindCallsWiderThanSmallBlindAgainstTheSameShove() {
    // The big blind is this model's best-grounded calling position; every other caller is
    // discounted below it (see CallingRange.callerPositionDiscount).
    for shover in [Position.utg, .hijack, .button] {
        let bbPct = CallingRange.callPercentage(caller: .bigBlind, shover: shover, effectiveStackBB: 10)!
        let sbPct = CallingRange.callPercentage(caller: .smallBlind, shover: shover, effectiveStackBB: 10)!
        #expect(bbPct > sbPct, "BB should call wider than SB against a \(shover) shove")
    }
}

@Test func callingSuitedHandNeverLoosesToItsOffsuitCounterpart() {
    // ChenScore only ever scores a suited hand >= its offsuit counterpart (the +2 suited
    // bonus), so if the offsuit version clears the calling threshold, the suited version
    // must too.
    for (offsuit, suited) in [("A9o", "A9s"), ("KJo", "KJs"), ("T8o", "T8s"), ("76o", "76s")] {
        let offsuitDecision = CallingRange.decideVsShove(
            hand: HoleCards(canonical: offsuit)!, caller: .bigBlind, shover: .cutoff, effectiveStackBB: 12
        )!
        let suitedDecision = CallingRange.decideVsShove(
            hand: HoleCards(canonical: suited)!, caller: .bigBlind, shover: .cutoff, effectiveStackBB: 12
        )!
        if offsuitDecision.action == .call {
            #expect(suitedDecision.action == .call, "\(suited) should call whenever \(offsuit) calls")
        }
    }
}

@Test func vsShoveReasoningMentionsCallingThreshold() {
    let decision = CallingRange.decideVsShove(
        hand: HoleCards(canonical: "AA")!, caller: .bigBlind, shover: .utg, effectiveStackBB: 10
    )!
    #expect(decision.reasoning.contains("calling threshold"))
}

// MARK: - Facing an open

@Test func premiumHandAlwaysThreeBetsAnOpen() {
    let aa = HoleCards(canonical: "AA")!
    for opener in Position.allCases {
        for defender in DefendingPosition.allCases where defender.actionOrderIndex > opener.actionOrderIndex {
            let decision = CallingRange.decideVsOpen(hand: aa, defender: defender, opener: opener, effectiveStackBB: 40)
            #expect(decision?.action == .threeBet, "AA should 3-bet \(opener)'s open from \(defender)")
        }
    }
}

@Test func trashHandFoldsToAnOpenFromEarlyPosition() {
    let trash = HoleCards(canonical: "72o")!
    let decision = CallingRange.decideVsOpen(hand: trash, defender: .bigBlind, opener: .utg, effectiveStackBB: 100)!
    #expect(decision.action == .fold)
}

@Test func vsOpenInvalidPositionPairingsReturnNil() {
    // UTG acts first — it can never be facing anyone else's open.
    for opener in Position.allCases {
        #expect(CallingRange.totalDefensePercentage(defender: .utg, opener: opener, effectiveStackBB: 40) == nil)
    }
    // A position can't face its own open.
    #expect(CallingRange.totalDefensePercentage(defender: .cutoff, opener: .cutoff, effectiveStackBB: 40) == nil)
    // Nor an open from someone who acts after it.
    #expect(CallingRange.totalDefensePercentage(defender: .hijack, opener: .button, effectiveStackBB: 40) == nil)
}

@Test func bigBlindCanFaceAnOpenFromEveryPosition() {
    for opener in Position.allCases {
        #expect(CallingRange.totalDefensePercentage(defender: .bigBlind, opener: opener, effectiveStackBB: 40) != nil)
    }
}

@Test func defenseWidensAgainstALaterOpenerAtTheSameStack() {
    // A button open is wider than a UTG open (OpeningRange itself), so there's less to
    // fear and more reason to defend against it.
    let vsUTG = CallingRange.totalDefensePercentage(defender: .bigBlind, opener: .utg, effectiveStackBB: 40)!
    let vsButton = CallingRange.totalDefensePercentage(defender: .bigBlind, opener: .button, effectiveStackBB: 40)!
    #expect(vsUTG < vsButton)
}

@Test func bigBlindDefendsWiderThanSmallBlindAgainstTheSameOpen() {
    for opener in [Position.utg, .hijack, .button] {
        let bbPct = CallingRange.totalDefensePercentage(defender: .bigBlind, opener: opener, effectiveStackBB: 40)!
        let sbPct = CallingRange.totalDefensePercentage(defender: .smallBlind, opener: opener, effectiveStackBB: 40)!
        #expect(bbPct > sbPct, "BB should defend wider than SB against a \(opener) open")
    }
}

@Test func threeBetThresholdIsAtLeastAsTightAsCallThreshold() {
    // 3-betting hands are a subset of the overall defending range, so the 3-bet score
    // threshold can never be looser than the call threshold.
    for opener in Position.allCases {
        for defender in DefendingPosition.allCases where defender.actionOrderIndex > opener.actionOrderIndex {
            let decision = CallingRange.decideVsOpen(
                hand: HoleCards(canonical: "AKs")!, defender: defender, opener: opener, effectiveStackBB: 40
            )!
            #expect(decision.threeBetThreshold >= decision.callThreshold)
        }
    }
}

@Test func defendingSuitedHandNeverLoosesToItsOffsuitCounterpart() {
    for (offsuit, suited) in [("A9o", "A9s"), ("KJo", "KJs"), ("T8o", "T8s"), ("76o", "76s")] {
        let offsuitDecision = CallingRange.decideVsOpen(
            hand: HoleCards(canonical: offsuit)!, defender: .bigBlind, opener: .cutoff, effectiveStackBB: 40
        )!
        let suitedDecision = CallingRange.decideVsOpen(
            hand: HoleCards(canonical: suited)!, defender: .bigBlind, opener: .cutoff, effectiveStackBB: 40
        )!
        // Fold < Call < 3-Bet in defensive strength; the suited version must be at least
        // as aggressive a defense as its offsuit counterpart.
        #expect(strength(suitedDecision.action) >= strength(offsuitDecision.action), "\(suited) should defend at least as much as \(offsuit)")
    }
}

private func strength(_ action: OpenDefenseAction) -> Int {
    switch action {
    case .fold: return 0
    case .call: return 1
    case .threeBet: return 2
    }
}

@Test func vsOpenReasoningMentionsThreshold() {
    let threeBetDecision = CallingRange.decideVsOpen(
        hand: HoleCards(canonical: "AA")!, defender: .bigBlind, opener: .utg, effectiveStackBB: 40
    )!
    #expect(threeBetDecision.reasoning.contains("3-bet threshold"))

    let foldDecision = CallingRange.decideVsOpen(
        hand: HoleCards(canonical: "72o")!, defender: .bigBlind, opener: .utg, effectiveStackBB: 40
    )!
    #expect(foldDecision.reasoning.contains("calling threshold"))
}

// MARK: - PreflopGrid integration

@Test func gridCallingDecisionsMatchDirectCallingRangeDecisions() {
    for row in 0..<PreflopGrid.ranks.count {
        for col in 0..<PreflopGrid.ranks.count {
            let hand = PreflopGrid.hands[row][col]
            let expected = CallingRange.decideVsShove(hand: hand, caller: .bigBlind, shover: .cutoff, effectiveStackBB: 10)!
            let actual = PreflopGrid.callingDecisions(caller: .bigBlind, shover: .cutoff, effectiveStackBB: 10)![row][col]
            #expect(actual.action == expected.action)
        }
    }
}

@Test func gridOpenDefenseDecisionsMatchDirectCallingRangeDecisions() {
    for row in 0..<PreflopGrid.ranks.count {
        for col in 0..<PreflopGrid.ranks.count {
            let hand = PreflopGrid.hands[row][col]
            let expected = CallingRange.decideVsOpen(hand: hand, defender: .bigBlind, opener: .cutoff, effectiveStackBB: 40)!
            let actual = PreflopGrid.openDefenseDecisions(defender: .bigBlind, opener: .cutoff, effectiveStackBB: 40)![row][col]
            #expect(actual.action == expected.action)
        }
    }
}

@Test func gridReturnsNilForInvalidPositionPairings() {
    #expect(PreflopGrid.callingDecisions(caller: .utg, shover: .button, effectiveStackBB: 10) == nil)
    #expect(PreflopGrid.openDefenseDecisions(defender: .utg, opener: .button, effectiveStackBB: 40) == nil)
}

@Test func defendingPositionSharesActionOrderWithPosition() {
    // The two enums declare their shared six cases in identical order, so a defender in
    // any of those six positions has the same action-order index as the matching
    // `Position` case — the invariant `PreflopGrid`'s nil-guards depend on.
    let shared: [(DefendingPosition, Position)] = [
        (.utg, .utg), (.middlePosition, .middlePosition), (.hijack, .hijack),
        (.cutoff, .cutoff), (.button, .button), (.smallBlind, .smallBlind),
    ]
    for (defending, position) in shared {
        #expect(defending.actionOrderIndex == position.actionOrderIndex)
    }
    #expect(DefendingPosition.bigBlind.actionOrderIndex == Position.allCases.count)
}
