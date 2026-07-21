import Testing
@testable import PokerKit

private func card(_ rank: Rank, _ suit: Suit) -> Card { Card(rank: rank, suit: suit) }

// MARK: - Category ordering (the ladder itself)

@Test func royalFlushBeatsQuads() {
    let royal = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.king, .spades), card(.queen, .spades), card(.jack, .spades), card(.ten, .spades),
    ])
    let quads = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.ace, .hearts), card(.ace, .diamonds), card(.ace, .clubs), card(.king, .spades),
    ])
    #expect(royal.category == .straightFlush)
    #expect(royal > quads)
}

@Test func quadsBeatsFullHouse() {
    let quads = HandEvaluator.bestHand(from: [
        card(.two, .spades), card(.two, .hearts), card(.two, .diamonds), card(.two, .clubs), card(.king, .spades),
    ])
    let fullHouse = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.ace, .hearts), card(.ace, .diamonds), card(.king, .clubs), card(.king, .spades),
    ])
    #expect(quads > fullHouse)
}

@Test func fullHouseBeatsFlush() {
    let fullHouse = HandEvaluator.bestHand(from: [
        card(.two, .spades), card(.two, .hearts), card(.two, .diamonds), card(.three, .clubs), card(.three, .spades),
    ])
    let flush = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.king, .spades), card(.queen, .spades), card(.jack, .spades), card(.nine, .spades),
    ])
    #expect(fullHouse > flush)
}

@Test func flushBeatsStraight() {
    let flush = HandEvaluator.bestHand(from: [
        card(.two, .spades), card(.four, .spades), card(.six, .spades), card(.eight, .spades), card(.ten, .spades),
    ])
    let straight = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.king, .hearts), card(.queen, .diamonds), card(.jack, .clubs), card(.ten, .spades),
    ])
    #expect(flush > straight)
}

@Test func straightBeatsTrips() {
    let straight = HandEvaluator.bestHand(from: [
        card(.six, .spades), card(.seven, .hearts), card(.eight, .diamonds), card(.nine, .clubs), card(.ten, .spades),
    ])
    let trips = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.ace, .hearts), card(.ace, .diamonds), card(.king, .clubs), card(.queen, .spades),
    ])
    #expect(straight > trips)
}

@Test func tripsBeatsTwoPair() {
    let trips = HandEvaluator.bestHand(from: [
        card(.two, .spades), card(.two, .hearts), card(.two, .diamonds), card(.three, .clubs), card(.four, .spades),
    ])
    let twoPair = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.ace, .hearts), card(.king, .diamonds), card(.king, .clubs), card(.queen, .spades),
    ])
    #expect(trips > twoPair)
}

@Test func twoPairBeatsPair() {
    let twoPair = HandEvaluator.bestHand(from: [
        card(.two, .spades), card(.two, .hearts), card(.three, .diamonds), card(.three, .clubs), card(.four, .spades),
    ])
    let pair = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.ace, .hearts), card(.king, .diamonds), card(.queen, .clubs), card(.jack, .spades),
    ])
    #expect(twoPair > pair)
}

@Test func pairBeatsHighCard() {
    let pair = HandEvaluator.bestHand(from: [
        card(.two, .spades), card(.two, .hearts), card(.three, .diamonds), card(.four, .clubs), card(.five, .spades),
    ])
    let highCard = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.king, .hearts), card(.queen, .diamonds), card(.jack, .clubs), card(.nine, .spades),
    ])
    #expect(pair > highCard)
}

// MARK: - The wheel (A-2-3-4-5)

@Test func wheelIsAStraightNotAceHigh() {
    let wheel = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.two, .hearts), card(.three, .diamonds), card(.four, .clubs), card(.five, .spades),
    ])
    #expect(wheel.category == .straight)
    #expect(wheel.tiebreakers == [5], "The wheel's straight high card is 5, not 14 (ace plays low here)")
}

@Test func wheelStraightLosesToSixHighStraight() {
    let wheel = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.two, .hearts), card(.three, .diamonds), card(.four, .clubs), card(.five, .spades),
    ])
    let sixHigh = HandEvaluator.bestHand(from: [
        card(.two, .spades), card(.three, .hearts), card(.four, .diamonds), card(.five, .clubs), card(.six, .spades),
    ])
    #expect(sixHigh > wheel)
}

@Test func wheelFlushIsAStraightFlushNotAHighCardFlush() {
    let wheel = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.two, .spades), card(.three, .spades), card(.four, .spades), card(.five, .spades),
    ])
    #expect(wheel.category == .straightFlush)
    #expect(wheel.tiebreakers == [5])
}

@Test func nearWheelRanksIsNotAStraight() {
    // A-2-3-4-6 skips 5 — not a straight in either direction.
    let notAStraight = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.two, .hearts), card(.three, .diamonds), card(.four, .clubs), card(.six, .spades),
    ])
    #expect(notAStraight.category == .highCard)
}

// MARK: - Kicker tie-breaks within a category

@Test func higherPairBeatsLowerPair() {
    let acePair = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.ace, .hearts), card(.two, .diamonds), card(.three, .clubs), card(.four, .spades),
    ])
    let kingPair = HandEvaluator.bestHand(from: [
        card(.king, .spades), card(.king, .hearts), card(.queen, .diamonds), card(.jack, .clubs), card(.ten, .spades),
    ])
    #expect(acePair > kingPair)
}

@Test func samePairHigherKickerWins() {
    let jackKicker = HandEvaluator.bestHand(from: [
        card(.two, .spades), card(.two, .hearts), card(.jack, .diamonds), card(.four, .clubs), card(.three, .spades),
    ])
    let tenKicker = HandEvaluator.bestHand(from: [
        card(.two, .clubs), card(.two, .diamonds), card(.ten, .spades), card(.four, .hearts), card(.three, .diamonds),
    ])
    #expect(jackKicker > tenKicker)
}

@Test func higherTopPairInTwoPairWins() {
    let acesAndTwos = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.ace, .hearts), card(.two, .diamonds), card(.two, .clubs), card(.king, .spades),
    ])
    let kingsAndQueens = HandEvaluator.bestHand(from: [
        card(.king, .clubs), card(.king, .diamonds), card(.queen, .spades), card(.queen, .hearts), card(.ace, .clubs),
    ])
    #expect(acesAndTwos > kingsAndQueens)
}

@Test func sameTopPairHigherSecondPairWins() {
    let acesAndKings = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.ace, .hearts), card(.king, .diamonds), card(.king, .clubs), card(.two, .spades),
    ])
    let acesAndQueens = HandEvaluator.bestHand(from: [
        card(.ace, .clubs), card(.ace, .diamonds), card(.queen, .spades), card(.queen, .hearts), card(.three, .clubs),
    ])
    #expect(acesAndKings > acesAndQueens)
}

@Test func fullHouseTripsRankBreaksTheTie() {
    let acesFullOfTwos = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.ace, .hearts), card(.ace, .diamonds), card(.two, .clubs), card(.two, .spades),
    ])
    let kingsFullOfQueens = HandEvaluator.bestHand(from: [
        card(.king, .clubs), card(.king, .diamonds), card(.king, .hearts), card(.queen, .spades), card(.queen, .clubs),
    ])
    #expect(acesFullOfTwos > kingsFullOfQueens)
}

@Test func sameTripsHigherPairBreaksTheFullHouseTie() {
    // Only possible across 7 cards (two different pairs can't both fit with the same trips
    // in just 5 cards) — exercises the 7-card `bestHand` path, not just `evaluate5`.
    let acesFullOfKings = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.ace, .hearts), card(.ace, .diamonds),
        card(.king, .clubs), card(.king, .spades), card(.two, .clubs), card(.three, .diamonds),
    ])
    let acesFullOfQueens = HandEvaluator.bestHand(from: [
        card(.ace, .clubs), card(.ace, .diamonds), card(.ace, .hearts),
        card(.queen, .spades), card(.queen, .hearts), card(.two, .spades), card(.three, .clubs),
    ])
    #expect(acesFullOfKings > acesFullOfQueens)
}

@Test func flushHighCardBreaksTheTie() {
    let aceHighFlush = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.jack, .spades), card(.eight, .spades), card(.five, .spades), card(.two, .spades),
    ])
    let kingHighFlush = HandEvaluator.bestHand(from: [
        card(.king, .hearts), card(.queen, .hearts), card(.nine, .hearts), card(.six, .hearts), card(.three, .hearts),
    ])
    #expect(aceHighFlush > kingHighFlush)
}

@Test func highCardKickersBreakTheTieInOrder() {
    let higherSecondCard = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.jack, .hearts), card(.eight, .diamonds), card(.five, .clubs), card(.two, .spades),
    ])
    let lowerSecondCard = HandEvaluator.bestHand(from: [
        card(.ace, .clubs), card(.ten, .diamonds), card(.nine, .spades), card(.six, .hearts), card(.three, .clubs),
    ])
    #expect(higherSecondCard > lowerSecondCard)
}

@Test func identicalRanksAreEqualRegardlessOfSuit() {
    let a = HandEvaluator.bestHand(from: [
        card(.ace, .spades), card(.king, .hearts), card(.queen, .diamonds), card(.jack, .clubs), card(.nine, .spades),
    ])
    let b = HandEvaluator.bestHand(from: [
        card(.ace, .hearts), card(.king, .clubs), card(.queen, .spades), card(.jack, .diamonds), card(.nine, .hearts),
    ])
    #expect(a == b)
}

// MARK: - 7-card best-of selection

@Test func sevenCardHandPicksTheBestFiveIgnoringTheRest() {
    // Board gives a flush; hole cards are irrelevant junk that shouldn't drag the result
    // down to two pair or worse.
    let hand = HandEvaluator.bestHand(from: [
        card(.two, .clubs), card(.three, .diamonds), // "hole cards" — junk, no pair, no flush help
        card(.four, .spades), card(.six, .spades), card(.eight, .spades), card(.ten, .spades), card(.queen, .spades),
    ])
    #expect(hand.category == .flush)
    #expect(hand.tiebreakers == [12, 10, 8, 6, 4])
}

@Test func sevenCardHandFindsTheStraightFlushOverTheSimpleFlush() {
    let hand = HandEvaluator.bestHand(from: [
        card(.nine, .spades), card(.ace, .hearts),
        card(.five, .spades), card(.six, .spades), card(.seven, .spades), card(.eight, .spades), card(.two, .diamonds),
    ])
    #expect(hand.category == .straightFlush)
    #expect(hand.tiebreakers == [9])
}

@Test func sixCardHandPicksTheBestFive() {
    let hand = HandEvaluator.bestHand(from: [
        card(.two, .clubs),
        card(.ace, .spades), card(.ace, .hearts), card(.ace, .diamonds), card(.king, .clubs), card(.king, .spades),
    ])
    #expect(hand.category == .fullHouse)
    #expect(hand.tiebreakers == [14, 13])
}
