import Testing
@testable import PokerKit

// MARK: - Fixtures
//
// Hand-written, representative PokerStars-format sample text (not real hand
// histories) covering: a hero win via a flop c-bet, a preflop fold, a PKO
// bounty knockout that runs all-in to showdown, and deliberately malformed
// text. Money amounts are chosen so the pot arithmetic is exact and easy to
// hand-verify in the comments below each fixture.

/// Hero (severeduck) opens from the cutoff, gets called by the big blind, then
/// wins the pot with an uncalled flop c-bet. 6-max, button on seat 4.
///
/// Preflop: SB posts 25 (dead), BB posts 50 then calls 50 more to 100 total,
/// hero (CO) raises to 100. Pot after preflop = 25 + 100 + 100 = 225.
/// Flop: hero bets 150, BB folds, bet returned, hero collects the 225 pot.
/// Hero invested 100 (preflop) + 150 (flop, returned) = 250; hero received
/// 150 (returned) + 225 (collected) = 375. Net = +125.
private let heroWinsWithFlopCBet = """
PokerStars Hand #250001: Tournament #900001, $10+$1 USD Hold'em No Limit - Level V (25/50) - 2026/02/01 18:05:11 ET
Table '900001 1' 6-max Seat #4 is the button
Seat 1: Player1 (3000 in chips)
Seat 2: Player2 (1500 in chips)
Seat 3: severeduck (2500 in chips)
Seat 4: Player4 (5000 in chips)
Seat 5: Player5 (2000 in chips)
Seat 6: Player6 (1800 in chips)
Player5: posts small blind 25
Player6: posts big blind 50
*** HOLE CARDS ***
Dealt to severeduck [Ah Kd]
Player1: folds
Player2: folds
severeduck: raises 50 to 100
Player4: folds
Player5: folds
Player6: calls 50
*** FLOP *** [2h 7d Jc]
Player6: checks
severeduck: bets 150
Player6: folds
Uncalled bet (150) returned to severeduck
severeduck collected 225 from pot
*** SUMMARY ***
Total pot 225 | Rake 0
Board [2h 7d Jc]
Seat 1: Player1 folded before Flop (didn't bet)
Seat 2: Player2 folded before Flop (didn't bet)
Seat 3: severeduck collected (225)
Seat 4: Player4 (button) folded before Flop (didn't bet)
Seat 5: Player5 (small blind) folded before Flop
Seat 6: Player6 (big blind) folded on the Flop
"""

/// Hero folds preflop and never sees a flop. Same table shape, button on seat 4,
/// hero on seat 1 (UTG).
private let heroFoldsPreflop = """
PokerStars Hand #250002: Tournament #900001, $10+$1 USD Hold'em No Limit - Level V (25/50) - 2026/02/01 18:07:41 ET
Table '900001 1' 6-max Seat #4 is the button
Seat 1: severeduck (2600 in chips)
Seat 2: Player2 (1500 in chips)
Seat 3: Player3 (2500 in chips)
Seat 4: Player4 (5000 in chips)
Seat 5: Player5 (2000 in chips)
Seat 6: Player6 (1800 in chips)
Player5: posts small blind 25
Player6: posts big blind 50
*** HOLE CARDS ***
Dealt to severeduck [7c 2d]
severeduck: folds
Player2: folds
Player3: raises 100 to 150
Player4: folds
Player5: folds
Player6: folds
Uncalled bet (100) returned to Player3
Player3 collected 175 from pot
*** SUMMARY ***
Total pot 175 | Rake 0
Seat 1: severeduck folded before Flop (didn't bet)
Seat 2: Player2 folded before Flop (didn't bet)
Seat 3: Player3 collected (175)
Seat 4: Player4 (button) folded before Flop (didn't bet)
Seat 5: Player5 (small blind) folded before Flop
Seat 6: Player6 (big blind) folded before Flop
"""

/// PKO bounty hand: hero (button, seat 2) shoves over a short stack's all-in
/// re-raise, both go to showdown, hero wins the pot and the opponent's bounty.
/// Seats are deliberately non-contiguous (1, 2, 3, 5) to exercise the
/// gap-tolerant position mapping.
///
/// Preflop: SB posts 25 (dead), ShortStack (BB) posts 50 then raises to 450
/// (all-in, +400), hero raises to 150 then calls the extra 300 to 450.
/// Pot = 25 + 450 + 450 = 925. Hero invested 450, hero collected 925 back.
/// Net = +475. Bounty: +3.00.
private let heroWinsBountyAtShowdown = """
PokerStars Hand #250003: Tournament #900002, $20+$5+$5 USD Hold'em No Limit PKO - Level II (25/50) - 2026/02/02 09:15:00 ET
Table '900002 1' 9-max Seat #2 is the button
Seat 1: Player1 (4000 in chips, $5.00 bounty)
Seat 2: severeduck (3000 in chips, $6.00 bounty)
Seat 3: Player3 (2200 in chips, $5.00 bounty)
Seat 5: ShortStack (450 in chips, $3.00 bounty)
Player3: posts small blind 25
ShortStack: posts big blind 50
*** HOLE CARDS ***
Dealt to severeduck [Kc Kh]
Player1: folds
severeduck: raises 100 to 150
Player3: folds
ShortStack: raises 400 to 450 and is all-in
severeduck: calls 300
*** FLOP *** [2h 7d Jc]
*** TURN *** [2h 7d Jc] [4s]
*** RIVER *** [2h 7d Jc 4s] [9d]
*** SHOW DOWN ***
severeduck: shows [Kc Kh] (a pair of Kings)
ShortStack: shows [Ac Qd] (high card Ace)
severeduck collected 925 from pot
ShortStack finished the tournament in 27th place
severeduck wins $3.00 for eliminating ShortStack and their own bounty increases by $3.00 to $9.00
*** SUMMARY ***
Total pot 925 | Rake 0
Board [2h 7d Jc 4s 9d]
Seat 1: Player1 (cutoff) folded before Flop (didn't bet)
Seat 2: severeduck (button) showed [Kc Kh] and won (925) with a pair of Kings
Seat 3: Player3 (small blind) folded before Flop
Seat 5: ShortStack (big blind) showed [Ac Qd] and lost with high card Ace
"""

private let garbageBlock = """
PokerStars Hand #999999: Tournament #1, garbage line with no seats, no button, no hole cards
This is not a valid hand history body at all.
"""

// MARK: - Hero wins with a flop c-bet

@Test func parsesHeaderFields() {
    let file = HandHistoryParser.parse(heroWinsWithFlopCBet)
    #expect(file.hands.count == 1)
    let hand = file.hands[0]
    #expect(hand.handId == "250001")
    #expect(hand.tournamentId == "900001")
    #expect(hand.smallBlind == 25)
    #expect(hand.bigBlind == 50)
    #expect(hand.date != nil)
}

@Test func parsesHeroHoleCardsAndStack() throws {
    let hand = HandHistoryParser.parse(heroWinsWithFlopCBet).hands[0]
    #expect(hand.heroName == "severeduck")
    #expect(hand.heroSeat == 3)
    #expect(hand.heroStartingStack == 2500)
    let cards = try #require(hand.heroHoleCards)
    #expect(cards.notation == "AKo")
}

@Test func detectsPositionForSixMaxTable() {
    let hand = HandHistoryParser.parse(heroWinsWithFlopCBet).hands[0]
    // Button is seat 4; hero on seat 3 is one seat before the button: cutoff.
    #expect(hand.heroPosition == "CO")
}

@Test func parsesBoardAndActionsPerStreet() {
    let hand = HandHistoryParser.parse(heroWinsWithFlopCBet).hands[0]
    #expect(hand.board.map(\.description) == ["2♥", "7♦", "J♣"])

    let heroActions = hand.actions.filter { $0.player == "severeduck" }
    #expect(heroActions.map(\.street) == [.preflop, .flop])
    #expect(heroActions.map(\.kind) == [.raise, .bet])
}

@Test func computesHeroNetChipsAndResult() {
    let hand = HandHistoryParser.parse(heroWinsWithFlopCBet).hands[0]
    #expect(hand.heroNetChips == 125)
    #expect(hand.heroWonHand == true)
    #expect(hand.heroSawFlop == true)
    #expect(hand.heroBountyWon == nil)
}

// MARK: - Hero folds preflop

@Test func foldedPreflopHandNeverSeesFlop() {
    let hand = HandHistoryParser.parse(heroFoldsPreflop).hands[0]
    #expect(hand.board.isEmpty)
    #expect(hand.heroSawFlop == false)
    #expect(hand.heroNetChips == 0)
    #expect(hand.heroWonHand == false)
    #expect(hand.heroPosition == "UTG")
}

// MARK: - Bounty / PKO hand

@Test func parsesBountyAndNetChipsForKnockoutHand() {
    let hand = HandHistoryParser.parse(heroWinsBountyAtShowdown).hands[0]
    #expect(hand.heroBountyWon == 3.00)
    #expect(hand.heroNetChips == 475)
    #expect(hand.heroWonHand == true)
}

@Test func allInPreflopRunoutStillCountsAsSeeingTheFlop() {
    // Both players are all-in preflop, so PokerStars logs zero action lines on
    // the flop/turn/river — hero must still be marked as having seen the flop.
    let hand = HandHistoryParser.parse(heroWinsBountyAtShowdown).hands[0]
    #expect(hand.heroSawFlop == true)
    #expect(hand.board.count == 5)
}

@Test func detectsPositionWithNonContiguousSeatNumbers() {
    // Seats present are 1, 2, 3, 5 (seat 4 is empty); button is seat 2.
    let hand = HandHistoryParser.parse(heroWinsBountyAtShowdown).hands[0]
    #expect(hand.heroSeat == 2)
    #expect(hand.heroPosition == "BTN")
}

// MARK: - Malformed input

@Test func malformedHandIsSkippedNotCrashed() {
    let file = HandHistoryParser.parse(garbageBlock)
    #expect(file.hands.isEmpty)
    #expect(file.skipped.count == 1)
    #expect(file.skipped[0].reason.isEmpty == false)
}

@Test func fileWithNoRecognizableHandsProducesEmptyResult() {
    let file = HandHistoryParser.parse("just some random notes\nnothing poker-shaped here\n")
    #expect(file.hands.isEmpty)
    #expect(file.skipped.isEmpty)
}

@Test func malformedHandDoesNotPreventOthersFromParsing() {
    let combined = [heroWinsWithFlopCBet, garbageBlock, heroFoldsPreflop].joined(separator: "\n\n")
    let file = HandHistoryParser.parse(combined)
    #expect(file.hands.count == 2)
    #expect(file.skipped.count == 1)
    #expect(Set(file.hands.map(\.handId)) == ["250001", "250002"])
}

// MARK: - Session grouping

@Test func groupsHandsIntoSessionsByTournamentId() {
    let combined = [heroWinsWithFlopCBet, heroFoldsPreflop, heroWinsBountyAtShowdown].joined(separator: "\n\n")
    let file = HandHistoryParser.parse(combined)
    let sessions = file.sessions
    #expect(sessions.count == 2)

    let session900001 = sessions.first { $0.tournamentId == "900001" }
    #expect(session900001?.hands.count == 2)
    #expect(session900001?.netChips == 125)
    #expect(session900001?.handsWithFlopSeen == 1)

    let session900002 = sessions.first { $0.tournamentId == "900002" }
    #expect(session900002?.hands.count == 1)
    #expect(session900002?.bountiesWon == 3.00)
}

// MARK: - Position mapping across table sizes

private func minimalHand(handId: String, seats: [(seat: Int, name: String)], buttonSeat: Int, heroSeat: Int) -> String {
    let heroName = seats.first { $0.seat == heroSeat }!.name
    var lines = [
        "PokerStars Hand #\(handId): Tournament #999000, $5+$0.50 USD Hold'em No Limit - Level I (10/20) - 2026/01/01 12:00:00 ET",
        "Table '999000 1' 9-max Seat #\(buttonSeat) is the button",
    ]
    for seat in seats.sorted(by: { $0.seat < $1.seat }) {
        lines.append("Seat \(seat.seat): \(seat.name) (1500 in chips)")
    }
    lines.append("*** HOLE CARDS ***")
    lines.append("Dealt to \(heroName) [2c 3d]")
    return lines.joined(separator: "\n")
}

@Test func positionLabelsForEverySeatAtEachTableSize() throws {
    let expectedLabelsByCount: [Int: [String]] = [
        2: ["BTN", "BB"],
        3: ["BTN", "SB", "BB"],
        4: ["BTN", "SB", "BB", "CO"],
        5: ["BTN", "SB", "BB", "HJ", "CO"],
        6: ["BTN", "SB", "BB", "UTG", "HJ", "CO"],
        7: ["BTN", "SB", "BB", "UTG", "MP", "HJ", "CO"],
        8: ["BTN", "SB", "BB", "UTG", "UTG+1", "MP", "HJ", "CO"],
        9: ["BTN", "SB", "BB", "UTG", "UTG+1", "MP", "MP+1", "HJ", "CO"],
    ]

    for (count, expectedLabels) in expectedLabelsByCount {
        let seats = (1...count).map { (seat: $0, name: "Player\($0)") }
        // Button fixed at seat 1: rotation is a no-op, so expectedLabels lines up seat-for-seat.
        for seat in 1...count {
            let text = minimalHand(handId: "\(count)0\(seat)", seats: seats, buttonSeat: 1, heroSeat: seat)
            let hand = try #require(HandHistoryParser.parse(text).hands.first)
            #expect(
                hand.heroPosition == expectedLabels[seat - 1],
                "seat \(seat) of \(count) expected \(expectedLabels[seat - 1]), got \(hand.heroPosition ?? "nil")"
            )
        }
    }
}
