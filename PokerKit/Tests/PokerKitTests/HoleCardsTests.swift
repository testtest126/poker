import Testing
@testable import PokerKit

@Test func holeCardsRejectsDuplicateCard() {
    let card = Card(rank: .ace, suit: .spades)
    #expect(HoleCards(card, card) == nil)
}

@Test func holeCardsDetectsPairSuitedOffsuit() {
    let aces = HoleCards(Card(rank: .ace, suit: .spades), Card(rank: .ace, suit: .hearts))!
    #expect(aces.isPair)
    #expect(aces.notation == "AA")

    let akSuited = HoleCards(Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades))!
    #expect(akSuited.isSuited)
    #expect(!akSuited.isPair)
    #expect(akSuited.notation == "AKs")

    let akOffsuit = HoleCards(Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .hearts))!
    #expect(!akOffsuit.isSuited)
    #expect(akOffsuit.notation == "AKo")
}

@Test func holeCardsCanonicalInitParsesNotation() {
    #expect(HoleCards(canonical: "AA")!.notation == "AA")
    #expect(HoleCards(canonical: "AKs")!.notation == "AKs")
    #expect(HoleCards(canonical: "T9o")!.notation == "T9o")
    #expect(HoleCards(canonical: "72o")!.notation == "72o")
    #expect(HoleCards(canonical: "invalid") == nil)
    #expect(HoleCards(canonical: "AKx") == nil)
}

@Test func holeCardsRandomProducesDistinctCards() {
    for _ in 0..<50 {
        let hand = HoleCards.random()
        #expect(hand.first != hand.second)
    }
}
