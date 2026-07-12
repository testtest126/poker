import Testing
@testable import PokerKit

/// Reference values from Bill Chen's published starting-hand formula.
@Test func chenScoreMatchesKnownPairs() {
    #expect(ChenScore.score(for: HoleCards(canonical: "AA")!) == 20)
    #expect(ChenScore.score(for: HoleCards(canonical: "KK")!) == 16)
    #expect(ChenScore.score(for: HoleCards(canonical: "QQ")!) == 14)
    #expect(ChenScore.score(for: HoleCards(canonical: "JJ")!) == 12)
    #expect(ChenScore.score(for: HoleCards(canonical: "TT")!) == 10)
    // Small pairs are floored at 5.
    #expect(ChenScore.score(for: HoleCards(canonical: "22")!) == 5)
    #expect(ChenScore.score(for: HoleCards(canonical: "33")!) == 5)
}

@Test func chenScoreMatchesKnownBroadwayHands() {
    #expect(ChenScore.score(for: HoleCards(canonical: "AKs")!) == 12)
    #expect(ChenScore.score(for: HoleCards(canonical: "AKo")!) == 10)
    #expect(ChenScore.score(for: HoleCards(canonical: "AQs")!) == 11)
}

@Test func chenScoreMatchesKnownConnectors() {
    // Suited connector below a queen gets the +1 straight-potential bonus.
    #expect(ChenScore.score(for: HoleCards(canonical: "T9s")!) == 8)
}

@Test func chenScoreRanksWorstHandLowest() {
    // 72o is the canonical "worst starting hand" — famously scores -1.
    let worst = ChenScore.score(for: HoleCards(canonical: "72o")!)
    #expect(worst == -1)

    for rankChar in ["A", "K", "Q", "J", "T", "9", "8", "7", "6", "5", "4", "3"] {
        for suffix in ["s", "o"] {
            let hand = HoleCards(canonical: "\(rankChar)2\(suffix)")!
            #expect(ChenScore.score(for: hand) >= worst)
        }
    }
}

@Test func chenScoreOrdersPremiumHandsAboveTrash() {
    let premium = ChenScore.score(for: HoleCards(canonical: "AA")!)
    let trash = ChenScore.score(for: HoleCards(canonical: "72o")!)
    #expect(premium > trash)
}
