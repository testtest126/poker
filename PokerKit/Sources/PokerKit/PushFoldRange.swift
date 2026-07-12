import Foundation

public enum PushFoldAction: String, Sendable {
    case push = "Push"
    case fold = "Fold"
}

public struct PushFoldDecision: Sendable {
    public let action: PushFoldAction
    public let handScore: Double
    public let scoreThreshold: Double
    public let shovePercentage: Double

    /// A short, human-readable justification for the trainer's feedback screen.
    public var reasoning: String {
        let pct = String(format: "%.0f", shovePercentage)
        switch action {
        case .push:
            return "Hand strength score \(formatted(handScore)) clears the shove threshold of "
                + "\(formatted(scoreThreshold)) (top \(pct)% of hands) for this position and stack."
        case .fold:
            return "Hand strength score \(formatted(handScore)) is below the shove threshold of "
                + "\(formatted(scoreThreshold)) (top \(pct)% of hands) for this position and stack."
        }
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}

/// An approximate, unopened-pot preflop push/fold model for short-stacked play
/// (roughly 1-20bb effective), the classic MTT short-stack spot.
///
/// This is a **study aid, not a solver**. Real Nash/ICM-optimal push/fold ranges come
/// from equilibrium computation (e.g. HoldemResources Calculator, ICMIZER) that accounts
/// for exact stack sizes, payout structure, and opponent stacks. What's encoded here is
/// a hand-tuned approximation of the general *shape* of published unopened shove charts:
/// tighter up front, much wider on the button/small blind, and wider still as the stack
/// gets shorter. It ranks the 169 starting hands with the well-documented Chen formula
/// (`ChenScore`) rather than a memorized equity table, then reads off a shove percentage
/// from the `shovePercentByPosition` data table below.
///
/// To refine this later: replace `shovePercentByPosition` with solved percentages (or
/// swap in a per-hand lookup table entirely) — the rest of the pipeline doesn't change.
public enum PushFoldRange {
    /// Stack breakpoints (effective bb), ascending. Percentages below are only defined
    /// at these points; `shovePercentage` linearly interpolates between them and clamps
    /// outside [1, 20].
    private static let breakpoints: [Double] = [1, 2, 3, 5, 7, 10, 12, 15, 17, 20]

    /// % of the 169 starting hands to shove, indexed by position then aligned 1:1 with
    /// `breakpoints`. Widens as the stack shortens; widens as position gets later.
    private static let shovePercentByPosition: [Position: [Double]] = [
        .utg:           [90, 60, 47, 33, 25, 18, 15, 11, 9, 7],
        .middlePosition: [93, 66, 53, 39, 30, 22, 18, 14, 11, 9],
        .hijack:        [95, 71, 59, 45, 35, 26, 22, 17, 14, 11],
        .cutoff:        [97, 78, 67, 53, 43, 33, 28, 22, 18, 15],
        .button:        [99, 88, 78, 66, 56, 45, 38, 31, 26, 22],
        .smallBlind:    [100, 96, 90, 80, 70, 58, 50, 41, 35, 30],
    ]

    /// All 169 canonical starting hands, ranked by Chen score, highest first.
    /// Computed once from the formula rather than memorized.
    static let rankedCanonicalScores: [Double] = {
        var scores: [Double] = []
        let ranks = Rank.allCases
        for i in 0..<ranks.count {
            let high = ranks[i]
            scores.append(ChenScore.score(for: HoleCards(Card(rank: high, suit: .clubs), Card(rank: high, suit: .diamonds))!))
            for j in 0..<i {
                let low = ranks[j]
                scores.append(ChenScore.score(for: HoleCards(Card(rank: high, suit: .clubs), Card(rank: low, suit: .clubs))!)) // suited
                scores.append(ChenScore.score(for: HoleCards(Card(rank: high, suit: .clubs), Card(rank: low, suit: .diamonds))!)) // offsuit
            }
        }
        return scores.sorted(by: >)
    }()

    public static func shovePercentage(position: Position, effectiveStackBB: Double) -> Double {
        let table = shovePercentByPosition[position]!
        let stack = min(max(effectiveStackBB, breakpoints.first!), breakpoints.last!)

        guard let upperIndex = breakpoints.firstIndex(where: { $0 >= stack }) else {
            return table.last!
        }
        if breakpoints[upperIndex] == stack || upperIndex == 0 {
            return table[upperIndex]
        }

        let lowerIndex = upperIndex - 1
        let lowerBB = breakpoints[lowerIndex]
        let upperBB = breakpoints[upperIndex]
        let fraction = (stack - lowerBB) / (upperBB - lowerBB)
        return table[lowerIndex] + fraction * (table[upperIndex] - table[lowerIndex])
    }

    /// The minimum Chen score that falls within the given shove percentage.
    public static func scoreThreshold(forPercentage percentage: Double) -> Double {
        let count = min(max(Int((Double(rankedCanonicalScores.count) * percentage / 100).rounded()), 1), rankedCanonicalScores.count)
        return rankedCanonicalScores[count - 1]
    }

    public static func decide(hand: HoleCards, position: Position, effectiveStackBB: Double) -> PushFoldDecision {
        let percentage = shovePercentage(position: position, effectiveStackBB: effectiveStackBB)
        let threshold = scoreThreshold(forPercentage: percentage)
        let handScore = ChenScore.score(for: hand)
        let action: PushFoldAction = handScore >= threshold ? .push : .fold
        return PushFoldDecision(action: action, handScore: handScore, scoreThreshold: threshold, shovePercentage: percentage)
    }
}
