import Foundation

public enum OpeningAction: String, Sendable {
    case raise = "Raise"
    case fold = "Fold"
}

public struct OpeningDecision: Sendable {
    public let action: OpeningAction
    public let handScore: Double
    public let scoreThreshold: Double
    public let openPercentage: Double

    /// A short, human-readable justification for the range viewer's detail view.
    public var reasoning: String {
        let pct = String(format: "%.0f", openPercentage)
        switch action {
        case .raise:
            return "Hand strength score \(formatted(handScore)) clears the open-raise threshold of "
                + "\(formatted(scoreThreshold)) (top \(pct)% of hands) for this position and stack."
        case .fold:
            return "Hand strength score \(formatted(handScore)) is below the open-raise threshold of "
                + "\(formatted(scoreThreshold)) (top \(pct)% of hands) for this position and stack."
        }
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}

/// An approximate, unopened-pot **opening (raise-first-in)** range model for standard
/// tournament stack depths (roughly 20-100bb) — the "should I open-raise this hand"
/// decision that covers most of an MTT before the stack gets short enough for
/// `PushFoldRange` to take over.
///
/// This is a **study aid, not a solver** — same posture as `PushFoldRange`, and for the
/// same reason: real GTO-solved opening ranges depend on exact stack depths, rake,
/// opponent tendencies, and postflop strategy in a way a static table can't capture.
/// What's encoded here is a hand-tuned approximation of the general *shape* of
/// widely-published open-raise charts: tight up front, widening through the button, wide
/// from the small blind (heads-up against the big blind). See `RANGES.md` for the exact
/// source basis, what's directly sourced vs. extrapolated, and one deliberate place this
/// table is tightened *below* its cited source out of caution (small blind).
///
/// Reuses `ChenScore` to rank the 169 starting hands (same ranking already used by
/// `PushFoldRange`) and `PushFoldRange.scoreThreshold(forPercentage:)` to turn a "top X%"
/// figure into a score cutoff — there is no second hand-ranking system in this codebase.
public enum OpeningRange {
    /// Stack breakpoints (effective bb), ascending. Percentages below are only anchored
    /// at these three points — deliberately fewer than `PushFoldRange`'s ten, because the
    /// source material backing this table is thinner across stack depths (see
    /// `RANGES.md`). `openPercentage` linearly interpolates between them and clamps
    /// outside [20, 100].
    private static let breakpoints: [Double] = [20, 40, 100]

    /// % of the 169 starting hands to open-raise, indexed by position then aligned 1:1
    /// with `breakpoints` (20bb, 40bb, 100bb). Narrows as the stack deepens; widens as
    /// position gets later. See `RANGES.md` for the source basis of each column.
    private static let openPercentByPosition: [Position: [Double]] = [
        .utg:            [16, 13, 10],
        .middlePosition: [24, 21, 18],
        .hijack:         [27, 24, 21],
        .cutoff:         [34, 31, 28],
        .button:         [49, 46, 43],
        .smallBlind:     [51, 48, 45],
    ]

    public static func openPercentage(position: Position, effectiveStackBB: Double) -> Double {
        let table = openPercentByPosition[position]!
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

    public static func decide(hand: HoleCards, position: Position, effectiveStackBB: Double) -> OpeningDecision {
        let percentage = openPercentage(position: position, effectiveStackBB: effectiveStackBB)
        let threshold = PushFoldRange.scoreThreshold(forPercentage: percentage)
        let handScore = ChenScore.score(for: hand)
        let action: OpeningAction = handScore >= threshold ? .raise : .fold
        return OpeningDecision(action: action, handScore: handScore, scoreThreshold: threshold, openPercentage: percentage)
    }
}
