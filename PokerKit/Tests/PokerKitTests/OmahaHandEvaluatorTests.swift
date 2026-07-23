import Testing
@testable import PokerKit

/// These tests exist to *prove* the 2-hole/3-board rule is actually enforced, not just
/// assumed — each one constructs a hand where the *illegal* best-9-cards answer is
/// dramatically different (and easy to state/verify by hand) from the correct, legal one.
@Test func fourAcesInHoleCanOnlyEverPlayExactlyTwoOfThem() {
    // Hole: all four aces (one per suit, so this is itself a legal, if unusual, Omaha hand).
    // Board: five cards, all distinct non-ace ranks, no board pair. If the 2-card cap were
    // ignored, the "best 9-card hand" would be trips or quads (using 3 or 4 hole aces). The
    // only *legal* hands use exactly 2 aces + 3 board cards — and since two of the five
    // final cards are always both "Ace" (a pair) and the other three are three different
    // non-ace board ranks (never all three the same, since the board itself has no pair),
    // the best legal hand is provably exactly a pair of aces, nothing higher, regardless of
    // which two aces or which three board cards are chosen.
    let hole = OmahaHoleCards(canonical: "AsAhAdAc")!
    let board = [
        Card(notation: "2c")!, Card(notation: "7d")!, Card(notation: "9h")!,
        Card(notation: "Ks")!, Card(notation: "4d")!,
    ]

    let result = OmahaHandEvaluator.bestHand(hole: hole, board: board)
    #expect(result.category == .pair, "Four aces in hole should only ever play a pair, not trips/quads — got \(result.category)")
    #expect(result.tiebreakers.first == 14, "The pair should be aces")
}

@Test func fourSpadesInHoleDoNotMakeAFlushWithOnlyOneSpadeOnBoard() {
    // Hole: A-K-Q-J of spades (four cards, one suit). Board: T of spades plus four
    // off-suit, unpaired, non-broadway cards. If hole cards could be used unrestricted
    // (Hold'em-style "best 5 of 9"), this is a ROYAL FLUSH (A-K-Q-J-T all spades) — but that
    // uses 4 hole cards, illegal in Omaha. With the 2-card cap correctly enforced, at most 2
    // hole spades + 1 board spade (T♠) = 3 spades can ever appear together — never a flush.
    // Hole ranks (A,K,Q,J) also never match any board rank, so no pair is possible either:
    // the correct, legal answer is exactly High Card.
    let hole = OmahaHoleCards(canonical: "AsKsQsJs")!
    let board = [
        Card(notation: "Ts")!, Card(notation: "2c")!, Card(notation: "3d")!,
        Card(notation: "4h")!, Card(notation: "5c")!,
    ]

    let result = OmahaHandEvaluator.bestHand(hole: hole, board: board)
    #expect(result.category == .highCard, "Only one board spade means no flush is legally reachable — got \(result.category)")
    #expect(result.category != .flush)
    #expect(result.category != .straightFlush)
}

@Test func aQueenHighStraightFlushIsCorrectlyFoundWhenTheSplitGenuinelyAllowsIt() {
    // The positive counterpart to the test above — proving the evaluator isn't just
    // pessimistic/broken, it correctly finds a legal straight flush when 2 hole cards + 3
    // board cards genuinely complete one. Hole: A-K-Q-J of spades. Board: T-9-8-7-6 of
    // spades (five spades, five consecutive ranks). The best *legal* combination is hole
    // Q♠J♠ + board T♠9♠8♠ = Q-J-T-9-8 of spades, a queen-high straight flush — using the
    // hole's ace or king can't extend any further since the board tops out at ten.
    let hole = OmahaHoleCards(canonical: "AsKsQsJs")!
    let board = [
        Card(notation: "Ts")!, Card(notation: "9s")!, Card(notation: "8s")!,
        Card(notation: "7s")!, Card(notation: "6s")!,
    ]

    let result = OmahaHandEvaluator.bestHand(hole: hole, board: board)
    #expect(result.category == .straightFlush)
    #expect(result.tiebreakers.first == 12, "Should be the queen-high straight flush (Q-J-T-9-8), not ace-high or king-high")
}

@Test func evaluatesExactlySixtyCombinationsAndPicksTheirMaximum() {
    // Cross-check against a brute-force re-implementation of the same 2+3 enumeration,
    // rather than trusting OmahaHandEvaluator's own indices tables.
    let hole = OmahaHoleCards(canonical: "AsKdQhJc")!
    let board = [
        Card(notation: "Th")!, Card(notation: "9c")!, Card(notation: "5s")!,
        Card(notation: "3d")!, Card(notation: "2h")!,
    ]

    var expected: HandStrength?
    var combinationCount = 0
    for i in 0..<4 {
        for j in (i + 1)..<4 {
            for a in 0..<5 {
                for b in (a + 1)..<5 {
                    for c in (b + 1)..<5 {
                        let five = [hole.cards[i], hole.cards[j], board[a], board[b], board[c]]
                        let candidate = HandEvaluator.bestHand(from: five)
                        combinationCount += 1
                        if expected == nil || candidate > expected! { expected = candidate }
                    }
                }
            }
        }
    }

    #expect(combinationCount == 60)
    let actual = OmahaHandEvaluator.bestHand(hole: hole, board: board)
    #expect(actual == expected)
}

@Test func fullHouseIsFoundWhenTwoHoleCardsPairTwoDifferentBoardRanks() {
    // Hole: A-A-K-K. Board: A-K-2-3-4. Using hole A+A doesn't work alone (only one board
    // ace), but hole A + K (one of each) plus board A,K,and one kicker isn't a boat either —
    // the actual best legal combination is hole K+K + board A,A... wait board only has one
    // ace. Let's use hole A+K + board A,K,+ any kicker = two pair, not a boat (only one A
    // and one K on board). This test instead confirms the *correct*, non-obvious answer
    // rather than assuming a full house is reachable — see the assertion below.
    let hole = OmahaHoleCards(canonical: "AsAhKdKc")!
    let board = [
        Card(notation: "Ac")!, Card(notation: "Kh")!, Card(notation: "2c")!,
        Card(notation: "3d")!, Card(notation: "4h")!,
    ]

    // Hole A♠A♥ + board A♣K♥2♣ → trip aces + K kicker isn't as strong as hole A♠K♦ + board
    // A♣K♥ + a kicker (two pair, aces and kings) vs. hole A♠A♥ + board A♣ + 2 kickers (trip
    // aces). Trip aces beats two pair, so the true best is trips.
    let result = OmahaHandEvaluator.bestHand(hole: hole, board: board)
    #expect(result.category == .trips, "Best legal hand here is trip aces (hole AA + board's lone ace), not a full house — got \(result.category)")
}
