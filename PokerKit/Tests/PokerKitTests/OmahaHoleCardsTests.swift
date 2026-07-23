import Testing
@testable import PokerKit

@Test func rejectsFewerOrMoreThanFourCards() {
    let a = Card(rank: .ace, suit: .spades)
    let k = Card(rank: .king, suit: .hearts)
    let q = Card(rank: .queen, suit: .diamonds)
    #expect(OmahaHoleCards([a, k, q]) == nil)
}

@Test func rejectsADuplicateCard() {
    let a = Card(rank: .ace, suit: .spades)
    let k = Card(rank: .king, suit: .hearts)
    let q = Card(rank: .queen, suit: .diamonds)
    #expect(OmahaHoleCards([a, a, k, q]) == nil)
}

@Test func acceptsFourDistinctCards() {
    let a = Card(rank: .ace, suit: .spades)
    let k = Card(rank: .king, suit: .hearts)
    let q = Card(rank: .queen, suit: .diamonds)
    let j = Card(rank: .jack, suit: .clubs)
    #expect(OmahaHoleCards([a, k, q, j]) != nil)
}

@Test func equalityAndHashingAreOrderIndependent() {
    let a = Card(rank: .ace, suit: .spades)
    let k = Card(rank: .king, suit: .hearts)
    let q = Card(rank: .queen, suit: .diamonds)
    let j = Card(rank: .jack, suit: .clubs)

    let handA = OmahaHoleCards([a, k, q, j])!
    let handB = OmahaHoleCards([j, q, k, a])!
    #expect(handA == handB)
    #expect(handA.hashValue == handB.hashValue)
}

@Test func notationRoundTripsThroughCanonical() {
    let a = Card(rank: .ace, suit: .spades)
    let k = Card(rank: .king, suit: .hearts)
    let q = Card(rank: .queen, suit: .diamonds)
    let j = Card(rank: .jack, suit: .clubs)
    let hand = OmahaHoleCards([a, k, q, j])!

    let notation = hand.notation
    #expect(notation.count == 8)
    let roundTripped = OmahaHoleCards(canonical: notation)
    #expect(roundTripped == hand)
}

@Test func canonicalParsesTheStandardExample() {
    let hand = OmahaHoleCards(canonical: "AsAhKdQc")
    #expect(hand != nil)
    #expect(hand?.cards.count == 4)
}

@Test func canonicalRejectsWrongLength() {
    #expect(OmahaHoleCards(canonical: "AsAhKd") == nil)
    #expect(OmahaHoleCards(canonical: "AsAhKdQcJc") == nil)
}

@Test func canonicalRejectsAnInvalidToken() {
    #expect(OmahaHoleCards(canonical: "AsAhKdXx") == nil)
}

@Test func canonicalRejectsARepeatedCard() {
    #expect(OmahaHoleCards(canonical: "AsAsKdQc") == nil)
}

@Test func suitPatternDetectsDoubleSuited() {
    let hand = OmahaHoleCards(canonical: "AsKsAhKh")!
    #expect(hand.suitPattern == .doubleSuited)
}

@Test func suitPatternDetectsSingleSuited() {
    let hand = OmahaHoleCards(canonical: "AsKsQhJd")!
    #expect(hand.suitPattern == .singleSuited)
}

@Test func suitPatternDetectsRainbow() {
    let hand = OmahaHoleCards(canonical: "AsKhQdJc")!
    #expect(hand.suitPattern == .rainbow)
}

@Test func suitPatternTreatsAFourFlushAsSingleSuited() {
    // Documented caveat: a 3- or 4-flush is structurally "one suit has 2+ cards," even
    // though only 2 of those cards can ever be used together (see OmahaHandEvaluator) —
    // this label is descriptive, not a strength claim.
    let hand = OmahaHoleCards(canonical: "AsKsQsJs")!
    #expect(hand.suitPattern == .singleSuited)
}

@Test func cardNotationRoundTrips() {
    for rank in Rank.allCases {
        for suit in Suit.allCases {
            let card = Card(rank: rank, suit: suit)
            let parsed = Card(notation: card.notation)
            #expect(parsed == card)
        }
    }
}

@Test func cardNotationParsingIsCaseInsensitiveOnSuit() {
    #expect(Card(notation: "As") == Card(notation: "AS"))
    #expect(Card(notation: "th") == Card(rank: .ten, suit: .hearts))
}

@Test func cardNotationRejectsGarbage() {
    #expect(Card(notation: "") == nil)
    #expect(Card(notation: "A") == nil)
    #expect(Card(notation: "Ax") == nil)
    #expect(Card(notation: "Zs") == nil)
}

@Test func randomProducesFourDistinctCards() {
    var rng: RandomNumberGenerator = SplitMix64(seed: 42)
    let hand = OmahaHoleCards.random(using: &rng)
    #expect(Set(hand.cards).count == 4)
}
