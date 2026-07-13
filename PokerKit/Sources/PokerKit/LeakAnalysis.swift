import Foundation

/// Preflop frequency stats over a set of hands: how often hero voluntarily entered the
/// pot, how often that entry was a raise, and how often it was a limp into an unopened
/// pot. Rates are `nil` when there are no hands to divide by, rather than reporting 0%.
public struct PreflopTendencies: Sendable, Equatable {
    public let handsPlayed: Int
    public let vpipCount: Int
    public let pfrCount: Int
    public let openLimpCount: Int

    public init(handsPlayed: Int, vpipCount: Int, pfrCount: Int, openLimpCount: Int) {
        self.handsPlayed = handsPlayed
        self.vpipCount = vpipCount
        self.pfrCount = pfrCount
        self.openLimpCount = openLimpCount
    }

    public var vpipRate: Double? { rate(vpipCount) }
    public var pfrRate: Double? { rate(pfrCount) }
    public var openLimpRate: Double? { rate(openLimpCount) }

    private func rate(_ count: Int) -> Double? {
        guard handsPlayed > 0 else { return nil }
        return Double(count) / Double(handsPlayed)
    }
}

/// Showdown frequency and chip result over a set of hands.
public struct ShowdownStats: Sendable, Equatable {
    public let handsPlayed: Int
    public let showdownCount: Int
    public let netChips: Decimal

    public init(handsPlayed: Int, showdownCount: Int, netChips: Decimal) {
        self.handsPlayed = handsPlayed
        self.showdownCount = showdownCount
        self.netChips = netChips
    }

    public var showdownRate: Double? {
        guard handsPlayed > 0 else { return nil }
        return Double(showdownCount) / Double(handsPlayed)
    }
}

/// Preflop tendencies and showdown/chip results for hands played from one position.
public struct PositionStats: Sendable, Equatable, Identifiable {
    public let position: String
    public let tendencies: PreflopTendencies
    public let showdown: ShowdownStats

    public init(position: String, tendencies: PreflopTendencies, showdown: ShowdownStats) {
        self.position = position
        self.tendencies = tendencies
        self.showdown = showdown
    }

    public var id: String { position }
}

/// One hand where hero's actual push/fold decision disagreed with `PushFoldRange`'s
/// recommendation, in an unopened short-stack spot.
public struct PushFoldDeviation: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable, Equatable {
        /// The model says shove; hero folded (or limped/min-raised instead of shoving).
        case missedShove
        /// The model says fold; hero shoved.
        case overShove
    }

    public let handId: String
    public let position: Position
    public let effectiveStackBB: Double
    public let hand: HoleCards
    public let recommended: PushFoldAction
    public let kind: Kind

    public init(handId: String, position: Position, effectiveStackBB: Double, hand: HoleCards, recommended: PushFoldAction, kind: Kind) {
        self.handId = handId
        self.position = position
        self.effectiveStackBB = effectiveStackBB
        self.hand = hand
        self.recommended = recommended
        self.kind = kind
    }

    public var id: String { handId }
}

/// Hero's push/fold decisions in unopened short-stack spots (hero effective stack
/// roughly 1-20bb, first to act or folded to), measured against `PushFoldRange`.
public struct PushFoldAdherenceReport: Sendable, Equatable {
    public let applicableSpots: Int
    public let matches: Int
    public let deviations: [PushFoldDeviation]

    public init(applicableSpots: Int, matches: Int, deviations: [PushFoldDeviation]) {
        self.applicableSpots = applicableSpots
        self.matches = matches
        self.deviations = deviations
    }

    public var adherenceRate: Double? {
        guard applicableSpots > 0 else { return nil }
        return Double(matches) / Double(applicableSpots)
    }

    public var missedShoves: [PushFoldDeviation] { deviations.filter { $0.kind == .missedShove } }
    public var overShoves: [PushFoldDeviation] { deviations.filter { $0.kind == .overShove } }
}

/// One short, human-readable leak finding. `isTentative` means the finding is backed
/// by fewer hands than the engine's confidence threshold — real, but not yet a verdict.
public struct LeakFinding: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
    public let isTentative: Bool

    public init(id: String, title: String, detail: String, isTentative: Bool) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isTentative = isTentative
    }
}

/// The full output of `LeakAnalysisEngine.analyze`: aggregate tendencies, a by-position
/// breakdown, push/fold adherence, and the top findings distilled from all of it.
public struct LeakReport: Sendable {
    public let overallTendencies: PreflopTendencies
    public let overallShowdown: ShowdownStats
    public let positionStats: [PositionStats]
    public let pushFoldAdherence: PushFoldAdherenceReport
    public let findings: [LeakFinding]
    public let minHandsForConfidence: Int
    public let minPushFoldSpotsForConfidence: Int

    public init(
        overallTendencies: PreflopTendencies,
        overallShowdown: ShowdownStats,
        positionStats: [PositionStats],
        pushFoldAdherence: PushFoldAdherenceReport,
        findings: [LeakFinding],
        minHandsForConfidence: Int,
        minPushFoldSpotsForConfidence: Int
    ) {
        self.overallTendencies = overallTendencies
        self.overallShowdown = overallShowdown
        self.positionStats = positionStats
        self.pushFoldAdherence = pushFoldAdherence
        self.findings = findings
        self.minHandsForConfidence = minHandsForConfidence
        self.minPushFoldSpotsForConfidence = minPushFoldSpotsForConfidence
    }
}

/// Turns a collection of imported hands into personalized, actionable feedback.
///
/// Everything here is derived from what `HandHistoryParser` actually captures — no
/// stat is fabricated to fill a gap the parser can't back. Push/fold adherence reuses
/// `PushFoldRange` (the same model behind the trainer and range viewer) rather than
/// introducing a second opinion on what "correct" looks like.
///
/// A note on "effective stack": true effective stack is the min of hero's stack and
/// every opponent's stack still in the hand. That's not something a single hand-history
/// line reliably gives us, so this approximates it with hero's own starting stack in bb,
/// which is the number that actually determines hero's own push/fold decision.
public enum LeakAnalysisEngine {
    public static let defaultMinHandsForConfidence = 20
    public static let defaultMinPushFoldSpotsForConfidence = 8

    /// Unopened-pot push/fold applies to UTG through SB — BB is excluded by design (see
    /// `Position`'s doc comment: if it folds around to BB, BB already won, no decision).
    /// UTG+1/MP+1 (8- and 9-max only) fold into the nearest coarser bucket the model has.
    private static let pushFoldPositionMap: [String: Position] = [
        "UTG": .utg, "UTG+1": .utg,
        "MP": .middlePosition, "MP+1": .middlePosition,
        "HJ": .hijack,
        "CO": .cutoff,
        "BTN": .button,
        "SB": .smallBlind,
    ]

    private static let positionOrder = ["UTG", "UTG+1", "MP", "MP+1", "HJ", "CO", "BTN", "SB", "BB"]

    public static func analyze(
        hands: [ParsedHand],
        minHandsForConfidence: Int = defaultMinHandsForConfidence,
        minPushFoldSpotsForConfidence: Int = defaultMinPushFoldSpotsForConfidence
    ) -> LeakReport {
        let overallTendencies = tendencies(for: hands)
        let overallShowdown = showdownStats(for: hands)
        let pushFold = pushFoldAdherence(for: hands)
        let findings = buildFindings(
            tendencies: overallTendencies,
            pushFold: pushFold,
            minHandsForConfidence: minHandsForConfidence,
            minPushFoldSpotsForConfidence: minPushFoldSpotsForConfidence
        )

        return LeakReport(
            overallTendencies: overallTendencies,
            overallShowdown: overallShowdown,
            positionStats: positionStats(for: hands),
            pushFoldAdherence: pushFold,
            findings: findings,
            minHandsForConfidence: minHandsForConfidence,
            minPushFoldSpotsForConfidence: minPushFoldSpotsForConfidence
        )
    }

    // MARK: - Preflop tendencies

    private static func tendencies(for hands: [ParsedHand]) -> PreflopTendencies {
        var vpip = 0
        var pfr = 0
        var limp = 0
        for hand in hands {
            let heroPreflop = hand.actions.filter { $0.street == .preflop && $0.player == hand.heroName }
            if heroPreflop.contains(where: { $0.kind == .call || $0.kind == .raise || $0.kind == .bet }) {
                vpip += 1
            }
            if heroPreflop.contains(where: { $0.kind == .raise }) {
                pfr += 1
            }
            if isOpenLimp(hand) {
                limp += 1
            }
        }
        return PreflopTendencies(handsPlayed: hands.count, vpipCount: vpip, pfrCount: pfr, openLimpCount: limp)
    }

    /// Index of hero's first preflop decision (fold/check/call/bet/raise) — the point in
    /// the hand where hero actually had a choice to make. Nil if hero never got to act
    /// preflop (e.g. everyone folded around to hero's big blind).
    private static func heroFirstPreflopActionIndex(_ hand: ParsedHand) -> Int? {
        hand.actions.firstIndex {
            $0.street == .preflop && $0.player == hand.heroName &&
                [.fold, .check, .call, .bet, .raise].contains($0.kind)
        }
    }

    /// True if nobody voluntarily entered the pot before hero's first preflop decision —
    /// hero is opening the action (or the first to act after posting a blind).
    private static func isUnopenedBeforeHero(_ hand: ParsedHand) -> Bool {
        guard let heroIndex = heroFirstPreflopActionIndex(hand) else { return false }
        let before = hand.actions[..<heroIndex].filter { $0.street == .preflop }
        return before.allSatisfy { [.fold, .postAnte, .postSmallBlind, .postBigBlind].contains($0.kind) }
    }

    private static func isOpenLimp(_ hand: ParsedHand) -> Bool {
        guard let heroIndex = heroFirstPreflopActionIndex(hand), hand.actions[heroIndex].kind == .call else {
            return false
        }
        return isUnopenedBeforeHero(hand)
    }

    // MARK: - Showdown & net chips

    private static func showdownStats(for hands: [ParsedHand]) -> ShowdownStats {
        let net = hands.reduce(Decimal(0)) { $0 + $1.heroNetChips }
        return ShowdownStats(handsPlayed: hands.count, showdownCount: hands.filter(\.wentToShowdown).count, netChips: net)
    }

    // MARK: - Position breakdown

    private static func positionStats(for hands: [ParsedHand]) -> [PositionStats] {
        let grouped = Dictionary(grouping: hands.filter { $0.heroPosition != nil }, by: { $0.heroPosition! })
        return grouped
            .map { position, hands in
                PositionStats(position: position, tendencies: tendencies(for: hands), showdown: showdownStats(for: hands))
            }
            .sorted { positionSortIndex($0.position) < positionSortIndex($1.position) }
    }

    private static func positionSortIndex(_ position: String) -> Int {
        positionOrder.firstIndex(of: position) ?? positionOrder.count
    }

    // MARK: - Push/fold adherence

    private static func pushFoldAdherence(for hands: [ParsedHand]) -> PushFoldAdherenceReport {
        var matches = 0
        var deviations: [PushFoldDeviation] = []

        for hand in hands {
            guard let label = hand.heroPosition, let position = pushFoldPositionMap[label] else { continue }
            guard let startingStack = hand.heroStartingStack, hand.bigBlind > 0 else { continue }
            let stackBB = (startingStack as NSDecimalNumber).doubleValue / (hand.bigBlind as NSDecimalNumber).doubleValue
            guard stackBB >= 1, stackBB <= 20 else { continue }
            guard let holeCards = hand.heroHoleCards else { continue }
            guard isUnopenedBeforeHero(hand) else { continue }

            let recommended = PushFoldRange.decide(hand: holeCards, position: position, effectiveStackBB: stackBB).action
            let heroShoved = hand.actions.contains {
                $0.street == .preflop && $0.player == hand.heroName && $0.kind == .raise && $0.isAllIn
            }
            let heroAction: PushFoldAction = heroShoved ? .push : .fold

            if heroAction == recommended {
                matches += 1
            } else {
                deviations.append(PushFoldDeviation(
                    handId: hand.handId,
                    position: position,
                    effectiveStackBB: stackBB,
                    hand: holeCards,
                    recommended: recommended,
                    kind: recommended == .push ? .missedShove : .overShove
                ))
            }
        }

        return PushFoldAdherenceReport(applicableSpots: matches + deviations.count, matches: matches, deviations: deviations)
    }

    // MARK: - Findings

    private static func buildFindings(
        tendencies: PreflopTendencies,
        pushFold: PushFoldAdherenceReport,
        minHandsForConfidence: Int,
        minPushFoldSpotsForConfidence: Int
    ) -> [LeakFinding] {
        var candidates: [(finding: LeakFinding, magnitude: Double)] = []

        if tendencies.openLimpCount > 0, let rate = tendencies.openLimpRate {
            let pct = rate * 100
            let tentative = tendencies.handsPlayed < minHandsForConfidence
            candidates.append((
                LeakFinding(
                    id: "open-limp",
                    title: "You open-limp \(formattedPercent(pct))% of hands",
                    detail: "\(tendencies.openLimpCount) of \(tendencies.handsPlayed) hands were open-limps into an unopened pot. "
                        + "The push/fold trainer never recommends limping — it's shove or fold."
                        + tentativeSuffix(tentative),
                    isTentative: tentative
                ),
                pct
            ))
        }

        let missedShoves = pushFold.missedShoves
        if !missedShoves.isEmpty, pushFold.applicableSpots > 0 {
            let pct = Double(missedShoves.count) / Double(pushFold.applicableSpots) * 100
            let tentative = pushFold.applicableSpots < minPushFoldSpotsForConfidence
            candidates.append((
                LeakFinding(
                    id: "missed-shoves",
                    title: "You folded \(missedShoves.count) spot\(missedShoves.count == 1 ? "" : "s") the model says to shove",
                    detail: "Out of \(pushFold.applicableSpots) unopened spots at \u{2264}20bb, \(missedShoves.count) were hands "
                        + "the push/fold model shoves but you folded (or limped) instead."
                        + tentativeSuffix(tentative),
                    isTentative: tentative
                ),
                pct
            ))
        }

        let overShoves = pushFold.overShoves
        if !overShoves.isEmpty, pushFold.applicableSpots > 0 {
            let pct = Double(overShoves.count) / Double(pushFold.applicableSpots) * 100
            let tentative = pushFold.applicableSpots < minPushFoldSpotsForConfidence
            candidates.append((
                LeakFinding(
                    id: "over-shoves",
                    title: "You shoved \(overShoves.count) spot\(overShoves.count == 1 ? "" : "s") the model says to fold",
                    detail: "Out of \(pushFold.applicableSpots) unopened spots at \u{2264}20bb, \(overShoves.count) were hands "
                        + "the push/fold model folds but you shoved."
                        + tentativeSuffix(tentative),
                    isTentative: tentative
                ),
                pct
            ))
        }

        return candidates
            .sorted { $0.magnitude > $1.magnitude }
            .prefix(3)
            .map(\.finding)
    }

    private static func tentativeSuffix(_ tentative: Bool) -> String {
        tentative ? " Small sample so far — treat this as a tentative signal, not a verdict." : ""
    }

    private static func formattedPercent(_ value: Double) -> String {
        String(format: "%.0f", value)
    }
}
