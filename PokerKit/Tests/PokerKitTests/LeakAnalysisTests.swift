import Testing
@testable import PokerKit

// MARK: - Fixtures
//
// All fixtures are 6-max, button on seat 1, blinds 25/50, so seat->position is fixed:
// 1=BTN, 2=SB, 3=BB, 4=UTG, 5=HJ, 6=CO. Hero's seat is chosen per fixture to land on
// the position each test needs. Stacks are chosen so effective stack in bb is exact
// and easy to hand-verify (1000 chips / 50bb = 20bb, etc).

private let table6Max = """
Table '600000 1' 6-max Seat #1 is the button
Seat 1: Player1 (2000 in chips)
Seat 2: Player2 (1000 in chips)
Seat 3: Player3 (1000 in chips)
"""

/// Hero (seat 4, UTG) opens with a raise, everyone folds. VPIP + PFR, not a limp.
/// Hero's raise of 150 exceeds what anyone could call (BB's 50), so 100 is returned
/// uncalled, then hero collects the remaining 125 pot (the two blinds plus the 50 of
/// the raise BB was on the hook for). Net = 225 (100 + 125 returned) - 150 (invested) = +75.
private let heroOpenRaises = """
PokerStars Hand #600001: Tournament #700001, $5+$0.50 USD Hold'em No Limit - Level I (25/50) - 2026/03/01 10:00:00 ET
\(table6Max)
Seat 4: hero (1000 in chips)
Seat 5: Player5 (1000 in chips)
Seat 6: Player6 (1000 in chips)
Player2: posts small blind 25
Player3: posts big blind 50
*** HOLE CARDS ***
Dealt to hero [Ac Kc]
hero: raises 100 to 150
Player5: folds
Player6: folds
Player1: folds
Player2: folds
Player3: folds
Uncalled bet (100) returned to hero
hero collected 125 from pot
"""

/// Hero (seat 4, UTG) folds preflop. Neither VPIP nor PFR nor a limp.
private let heroFoldsPreflop = """
PokerStars Hand #600002: Tournament #700001, $5+$0.50 USD Hold'em No Limit - Level I (25/50) - 2026/03/01 10:01:00 ET
\(table6Max)
Seat 4: hero (1000 in chips)
Seat 5: Player5 (1000 in chips)
Seat 6: Player6 (1000 in chips)
Player2: posts small blind 25
Player3: posts big blind 50
*** HOLE CARDS ***
Dealt to hero [7c 2d]
hero: folds
Player5: folds
Player6: folds
Player1: folds
Player2: folds
"""

/// Hero (seat 4, UTG) limps in first to act, then someone raises behind. VPIP, an
/// open-limp, but not a PFR (hero never raises).
private let heroOpenLimps = """
PokerStars Hand #600003: Tournament #700001, $5+$0.50 USD Hold'em No Limit - Level I (25/50) - 2026/03/01 10:02:00 ET
\(table6Max)
Seat 4: hero (1000 in chips)
Seat 5: Player5 (1000 in chips)
Seat 6: Player6 (1000 in chips)
Player2: posts small blind 25
Player3: posts big blind 50
*** HOLE CARDS ***
Dealt to hero [9c 8c]
hero: calls 50
Player5: folds
Player6: raises 150 to 200
Player1: folds
Player2: folds
Player3: folds
"""

/// Hero (seat 6, CO) cold-calls a raise made by UTG before hero acts. VPIP, but *not*
/// an open-limp — the pot was already opened before hero's call.
private let heroColdCalls = """
PokerStars Hand #600004: Tournament #700001, $5+$0.50 USD Hold'em No Limit - Level I (25/50) - 2026/03/01 10:03:00 ET
\(table6Max)
Seat 4: Player4 (1000 in chips)
Seat 5: Player5 (1000 in chips)
Seat 6: hero (1000 in chips)
Player2: posts small blind 25
Player3: posts big blind 50
*** HOLE CARDS ***
Dealt to hero [Qc Qd]
Player4: raises 100 to 150
Player5: folds
hero: calls 150
Player1: folds
Player2: folds
Player3: folds
"""

/// Hero (seat 2, SB) plays a full hand to showdown and wins. Used for wentToShowdown
/// and net-chips checks. Hero invests 25 (SB) + 175 (raise to 200) + 200 (flop) + 300
/// (turn) + 350 (river) = 1050, collects 2200 back. Net = +1150.
private let heroWinsAtShowdown = """
PokerStars Hand #600010: Tournament #700002, $5+$0.50 USD Hold'em No Limit - Level I (25/50) - 2026/03/01 11:00:00 ET
\(table6Max)
Seat 4: Player4 (1000 in chips)
Seat 5: Player5 (1000 in chips)
Seat 6: Player6 (1000 in chips)
hero: posts small blind 25
Player3: posts big blind 50
*** HOLE CARDS ***
Dealt to hero [Ac Ad]
Player4: folds
Player5: folds
Player6: folds
Player1: folds
hero: raises 150 to 200
Player3: calls 150
*** FLOP *** [2h 7d Jc]
hero: bets 200
Player3: calls 200
*** TURN *** [2h 7d Jc] [4s]
hero: bets 300
Player3: calls 300
*** RIVER *** [2h 7d Jc 4s] [9d]
hero: bets 350
Player3: calls 350
*** SHOW DOWN ***
hero: shows [Ac Ad] (a pair of Aces)
Player3: shows [Kd Kc] (a pair of Kings)
hero collected 2200 from pot
"""

/// Builds a UTG-vs-nobody push/fold spot: hero (seat 4) is first to act, 20bb effective
/// (1000 chips / 50bb), holding `cards`, taking `heroLine` as their only preflop action.
private func pushFoldSpotHand(handId: String, cards: String, heroLine: String) -> String {
    """
    PokerStars Hand #\(handId): Tournament #700003, $5+$0.50 USD Hold'em No Limit - Level I (25/50) - 2026/03/01 12:00:00 ET
    \(table6Max)
    Seat 4: hero (1000 in chips)
    Seat 5: Player5 (1000 in chips)
    Seat 6: Player6 (1000 in chips)
    Player2: posts small blind 25
    Player3: posts big blind 50
    *** HOLE CARDS ***
    Dealt to hero [\(cards)]
    \(heroLine)
    Player5: folds
    Player6: folds
    Player1: folds
    Player2: folds
    Player3: folds
    """
}

// AA at UTG 20bb: model shoves essentially always (top ~7% suffices).
private let pushFoldMatch = pushFoldSpotHand(handId: "600020", cards: "Ac Ad", heroLine: "hero: raises 950 to 1000 and is all-in")
// AA at UTG 20bb, but hero folds: model says push, hero folded -> missed shove.
private let pushFoldMissedShove = pushFoldSpotHand(handId: "600021", cards: "Ac Ad", heroLine: "hero: folds")
// 72o at UTG 20bb, textbook fold, but hero shoves -> over-shove.
private let pushFoldOverShove = pushFoldSpotHand(handId: "600022", cards: "7c 2d", heroLine: "hero: raises 950 to 1000 and is all-in")

/// Hero (seat 3, BB) — excluded from push/fold analysis by position, regardless of
/// action, since BB is never an unopened-pot decision (see `Position`'s doc comment).
private let pushFoldExcludedBB = """
PokerStars Hand #600023: Tournament #700003, $5+$0.50 USD Hold'em No Limit - Level I (25/50) - 2026/03/01 12:03:00 ET
\(table6Max)
Seat 4: Player4 (1000 in chips)
Seat 5: Player5 (1000 in chips)
Seat 6: Player6 (1000 in chips)
Player2: posts small blind 25
hero: posts big blind 50
*** HOLE CARDS ***
Dealt to hero [Ac Ad]
Player4: folds
Player5: folds
Player6: folds
Player1: folds
Player2: folds
"""

/// Hero (seat 4, UTG) at 30bb (1500 chips / 50bb) — outside the model's 1-20bb range.
private let pushFoldExcludedTooDeep = """
PokerStars Hand #600024: Tournament #700003, $5+$0.50 USD Hold'em No Limit - Level I (25/50) - 2026/03/01 12:04:00 ET
\(table6Max)
Seat 4: hero (1500 in chips)
Seat 5: Player5 (1000 in chips)
Seat 6: Player6 (1000 in chips)
Player2: posts small blind 25
Player3: posts big blind 50
*** HOLE CARDS ***
Dealt to hero [Ac Ad]
hero: raises 1450 to 1500 and is all-in
Player5: folds
Player6: folds
Player1: folds
Player2: folds
Player3: folds
"""

private func parse(_ text: String) -> ParsedHand {
    HandHistoryParser.parse(text).hands[0]
}

// MARK: - Preflop tendencies

@Test func vpipPfrAndOpenLimpAreCountedCorrectly() {
    let hands = [heroOpenRaises, heroFoldsPreflop, heroOpenLimps, heroColdCalls].map(parse)
    let report = LeakAnalysisEngine.analyze(hands: hands)
    let tendencies = report.overallTendencies

    #expect(tendencies.handsPlayed == 4)
    // Open-raise, open-limp, and cold-call all put money in voluntarily; the fold didn't.
    #expect(tendencies.vpipCount == 3)
    // Only the open-raise is a preflop raise from hero.
    #expect(tendencies.pfrCount == 1)
    // Only the open-limp is a limp into a genuinely unopened pot (the cold-call wasn't).
    #expect(tendencies.openLimpCount == 1)
}

@Test func ratesAreNilWithNoHands() {
    let report = LeakAnalysisEngine.analyze(hands: [])
    #expect(report.overallTendencies.vpipRate == nil)
    #expect(report.overallTendencies.pfrRate == nil)
    #expect(report.overallTendencies.openLimpRate == nil)
    #expect(report.overallShowdown.showdownRate == nil)
    #expect(report.pushFoldAdherence.adherenceRate == nil)
    #expect(report.findings.isEmpty)
}

// MARK: - Showdown & net chips

@Test func showdownAndNetChipsAreComputedFromParsedResults() {
    let hands = [heroOpenRaises, heroWinsAtShowdown].map(parse)
    let report = LeakAnalysisEngine.analyze(hands: hands)

    #expect(report.overallShowdown.handsPlayed == 2)
    #expect(report.overallShowdown.showdownCount == 1)
    // heroOpenRaises nets +75 (see its fixture comment), heroWinsAtShowdown nets +1150.
    #expect(report.overallShowdown.netChips == 1225)
}

// MARK: - Position breakdown

@Test func positionBreakdownGroupsAndOrdersByActingPosition() {
    let hands = [heroOpenRaises, heroFoldsPreflop, heroColdCalls].map(parse)
    let report = LeakAnalysisEngine.analyze(hands: hands)

    #expect(report.positionStats.map(\.position) == ["UTG", "CO"])
    let utg = report.positionStats[0]
    #expect(utg.tendencies.handsPlayed == 2)
    #expect(utg.tendencies.vpipCount == 1)
    let co = report.positionStats[1]
    #expect(co.tendencies.handsPlayed == 1)
    #expect(co.tendencies.vpipCount == 1)
}

// MARK: - Push/fold adherence

@Test func matchingShoveCountsAsAdherence() {
    let hands = [pushFoldMatch].map(parse)
    let report = LeakAnalysisEngine.analyze(hands: hands)
    #expect(report.pushFoldAdherence.applicableSpots == 1)
    #expect(report.pushFoldAdherence.matches == 1)
    #expect(report.pushFoldAdherence.deviations.isEmpty)
}

@Test func foldingAModelShoveIsAMissedShoveDeviation() {
    let hands = [pushFoldMissedShove].map(parse)
    let report = LeakAnalysisEngine.analyze(hands: hands)
    #expect(report.pushFoldAdherence.applicableSpots == 1)
    #expect(report.pushFoldAdherence.matches == 0)
    #expect(report.pushFoldAdherence.deviations.count == 1)
    #expect(report.pushFoldAdherence.deviations[0].kind == .missedShove)
    #expect(report.pushFoldAdherence.deviations[0].recommended == .push)
}

@Test func shovingAModelFoldIsAnOverShoveDeviation() {
    let hands = [pushFoldOverShove].map(parse)
    let report = LeakAnalysisEngine.analyze(hands: hands)
    #expect(report.pushFoldAdherence.applicableSpots == 1)
    #expect(report.pushFoldAdherence.matches == 0)
    #expect(report.pushFoldAdherence.deviations.count == 1)
    #expect(report.pushFoldAdherence.deviations[0].kind == .overShove)
    #expect(report.pushFoldAdherence.deviations[0].recommended == .fold)
}

@Test func bigBlindAndOutOfRangeStacksAreExcludedFromPushFoldSpots() {
    let hands = [pushFoldExcludedBB, pushFoldExcludedTooDeep, heroColdCalls].map(parse)
    let report = LeakAnalysisEngine.analyze(hands: hands)
    // BB is never a push/fold decision; 30bb is outside the model's 1-20bb range; the
    // cold-call wasn't an unopened pot. None of the three should count.
    #expect(report.pushFoldAdherence.applicableSpots == 0)
}

@Test func fullPushFoldMixReportsCorrectAdherenceRate() throws {
    let hands = [
        pushFoldMatch, pushFoldMissedShove, pushFoldOverShove,
        pushFoldExcludedBB, pushFoldExcludedTooDeep, heroColdCalls,
    ].map(parse)
    let report = LeakAnalysisEngine.analyze(hands: hands)

    #expect(report.pushFoldAdherence.applicableSpots == 3)
    #expect(report.pushFoldAdherence.matches == 1)
    #expect(report.pushFoldAdherence.missedShoves.count == 1)
    #expect(report.pushFoldAdherence.overShoves.count == 1)
    let rate = try #require(report.pushFoldAdherence.adherenceRate)
    #expect(abs(rate - (1.0 / 3.0)) < 0.0001)
}

// MARK: - Findings & sample-size gating

@Test func openLimpFindingIsTentativeBelowConfidenceThreshold() throws {
    let hands = [heroOpenLimps]
    let report = LeakAnalysisEngine.analyze(hands: hands.map(parse), minHandsForConfidence: 20)
    let finding = try #require(report.findings.first { $0.id == "open-limp" })
    #expect(finding.isTentative == true)
    #expect(finding.detail.contains("tentative"))
}

@Test func openLimpFindingIsNotTentativeAtOrAboveConfidenceThreshold() throws {
    // 3 hands, 1 of which is a limp, with the confidence bar set at the sample size.
    let hands = [heroOpenLimps, heroFoldsPreflop, heroOpenRaises].map(parse)
    let report = LeakAnalysisEngine.analyze(hands: hands, minHandsForConfidence: 3)
    let finding = try #require(report.findings.first { $0.id == "open-limp" })
    #expect(finding.isTentative == false)
}

@Test func pushFoldDeviationFindingsAreTentativeBelowSpotThreshold() throws {
    let hands = [pushFoldMissedShove, pushFoldOverShove].map(parse)
    let report = LeakAnalysisEngine.analyze(hands: hands, minPushFoldSpotsForConfidence: 8)
    let missed = try #require(report.findings.first { $0.id == "missed-shoves" })
    let over = try #require(report.findings.first { $0.id == "over-shoves" })
    #expect(missed.isTentative == true)
    #expect(over.isTentative == true)
}

@Test func noFindingsWhenPlayIsClean() {
    // Hero folds 72o unopened at UTG 20bb — exactly what the model recommends, so this
    // is a matching push/fold spot, not a deviation. No limp, no VPIP. Nothing to flag.
    let report = LeakAnalysisEngine.analyze(hands: [parse(heroFoldsPreflop)])
    #expect(report.findings.isEmpty)
}

@Test func findingsAreCappedAtThree() {
    let hands = [
        heroOpenLimps, heroOpenLimps, heroOpenLimps,
        pushFoldMissedShove, pushFoldOverShove,
    ]
    // Re-parse each fixture independently so hand IDs (used for de-duplication logic
    // elsewhere) don't matter here — the engine doesn't dedupe, it just counts.
    let report = LeakAnalysisEngine.analyze(hands: hands.map(parse))
    #expect(report.findings.count <= 3)
}
