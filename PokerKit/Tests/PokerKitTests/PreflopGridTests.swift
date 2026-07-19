import Testing
@testable import PokerKit

@Test func gridEnumeratesAll169UniqueHands() {
    let notations = Set(PreflopGrid.hands.flatMap { $0 }.map(\.notation))
    #expect(notations.count == 169)
}

@Test func diagonalCellsArePairs() {
    for i in 0..<PreflopGrid.ranks.count {
        #expect(PreflopGrid.hands[i][i].isPair)
    }
}

@Test func upperRightIsSuitedLowerLeftIsOffsuit() {
    for row in 0..<PreflopGrid.ranks.count {
        for col in 0..<PreflopGrid.ranks.count where row != col {
            let hand = PreflopGrid.hands[row][col]
            if row < col {
                #expect(hand.isSuited, "(\(row),\(col)) should be suited: \(hand.notation)")
            } else {
                #expect(!hand.isSuited, "(\(row),\(col)) should be offsuit: \(hand.notation)")
            }
        }
    }
}

@Test func notationMatchesGridPosition() {
    // A is index 0, K is index 1: (0,1) is above the diagonal -> AKs.
    #expect(PreflopGrid.notation(row: 0, col: 1) == "AKs")
    // (1,0) is below the diagonal -> AKo.
    #expect(PreflopGrid.notation(row: 1, col: 0) == "AKo")
    // AA sits at (0,0).
    #expect(PreflopGrid.notation(row: 0, col: 0) == "AA")
}

@Test func gridDecisionsMatchDirectPushFoldRangeDecisions() {
    for row in 0..<PreflopGrid.ranks.count {
        for col in 0..<PreflopGrid.ranks.count {
            let hand = PreflopGrid.hands[row][col]
            let expected = PushFoldRange.decide(hand: hand, position: .cutoff, effectiveStackBB: 8)
            let actual = PreflopGrid.decisions(position: .cutoff, effectiveStackBB: 8)[row][col]
            #expect(actual.action == expected.action)
        }
    }
}

@Test func aaAlwaysShovesAcrossGrid() {
    for position in Position.allCases {
        for stack: Double in [1, 5, 10, 15, 20] {
            let decisions = PreflopGrid.decisions(position: position, effectiveStackBB: stack)
            #expect(decisions[0][0].action == .push, "AA should shove from \(position) at \(stack)bb")
        }
    }
}

@Test func gridOpeningDecisionsMatchDirectOpeningRangeDecisions() {
    for row in 0..<PreflopGrid.ranks.count {
        for col in 0..<PreflopGrid.ranks.count {
            let hand = PreflopGrid.hands[row][col]
            let expected = OpeningRange.decide(hand: hand, position: .cutoff, effectiveStackBB: 60)
            let actual = PreflopGrid.openingDecisions(position: .cutoff, effectiveStackBB: 60)[row][col]
            #expect(actual.action == expected.action)
        }
    }
}

@Test func aaAlwaysOpensAcrossGrid() {
    for position in Position.allCases {
        for stack: Double in [20, 40, 60, 100] {
            let decisions = PreflopGrid.openingDecisions(position: position, effectiveStackBB: stack)
            #expect(decisions[0][0].action == .raise, "AA should open from \(position) at \(stack)bb")
        }
    }
}

@Test func sevenTwoOffsuitOnlyShovesAtVeryShortStacks() {
    let sevenIndex = PreflopGrid.ranks.firstIndex(of: .seven)!
    let twoIndex = PreflopGrid.ranks.firstIndex(of: .two)!
    // Offsuit cell is below the diagonal: row is the lower rank's index.
    let row = max(sevenIndex, twoIndex)
    let col = min(sevenIndex, twoIndex)
    #expect(PreflopGrid.hands[row][col].notation == "72o")

    let deepUTG = PreflopGrid.decisions(position: .utg, effectiveStackBB: 20)
    #expect(deepUTG[row][col].action == .fold)

    let shortSB = PreflopGrid.decisions(position: .smallBlind, effectiveStackBB: 1)
    #expect(shortSB[row][col].action == .push)
}
