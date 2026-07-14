import Foundation

/// A single position + stack-range region to drill, derived from where the user's own
/// push/fold play actually deviates from `PushFoldRange` most often. `dominantKind` is
/// whichever deviation type (missed shove or over-shove) is more common within that
/// region, used purely for the human-readable explanation — the drill itself deals
/// random hands in the region so the user practices the boundary either way.
public struct DrillFocus: Sendable, Equatable {
    public let position: Position
    public let stackRange: ClosedRange<Int>
    public let dominantKind: PushFoldDeviation.Kind
    public let deviationCount: Int
    public let isTentative: Bool

    public init(
        position: Position,
        stackRange: ClosedRange<Int>,
        dominantKind: PushFoldDeviation.Kind,
        deviationCount: Int,
        isTentative: Bool
    ) {
        self.position = position
        self.stackRange = stackRange
        self.dominantKind = dominantKind
        self.deviationCount = deviationCount
        self.isTentative = isTentative
    }

    /// A short, human-readable explanation of why these spots were chosen, meant for
    /// display on the drill screen so the personalization is legible, not a black box.
    public var explanation: String {
        let kindText = dominantKind == .missedShove ? "missed shoves" : "over-shoves"
        let stackText = stackRange.lowerBound == stackRange.upperBound
            ? "\(stackRange.lowerBound)bb"
            : "\(stackRange.lowerBound)\u{2013}\(stackRange.upperBound)bb"
        var text = "Focused on: \(kindText), \(stackText), \(position.rawValue) \u{2014} your weakest area from your last import."
        if isTentative {
            text += " Small sample so far — treat this as a tentative signal, not a verdict."
        }
        return text
    }
}

/// Turns a `LeakReport` into a weighted stream of `PushFoldSpot`s that drill the user's
/// own leaks, closing the loop from import -> leak finding -> targeted practice.
///
/// Reuses `PushFoldRange` for the "correct" answer (there's no second opinion on what
/// correct looks like) and `PushFoldSpot` for dealing — this only decides *which*
/// position/stack region spots get drawn from.
public enum DrillGenerator {
    /// Fraction of dealt spots pulled from the focus region once one is found. Kept
    /// below 1.0 so a focused session still surfaces some variety rather than only ever
    /// showing the one leaked region.
    public static let defaultFocusWeight = 0.7

    /// Finds the single position + stack range where the user's push/fold deviations
    /// concentrate most. Nil if there are no deviations to learn from — either no
    /// applicable push/fold spots yet (not enough imported hands) or the user's play at
    /// those spots was clean.
    public static func focus(from report: LeakReport) -> DrillFocus? {
        let deviations = report.pushFoldAdherence.deviations
        guard !deviations.isEmpty else { return nil }

        let grouped = Dictionary(grouping: deviations, by: \.position)
        let orderIndex = Dictionary(uniqueKeysWithValues: Position.allCases.enumerated().map { ($1, $0) })

        // Strict total order (count, then position) so ties resolve the same way every
        // time — `Dictionary`'s own iteration order is not stable across runs.
        let best = grouped.max { lhs, rhs in
            lhs.value.count != rhs.value.count
                ? lhs.value.count < rhs.value.count
                : orderIndex[lhs.key]! < orderIndex[rhs.key]!
        }!

        let position = best.key
        let group = best.value
        let stacks = group.map(\.effectiveStackBB)
        let low = Int(stacks.min()!.rounded(.down))
        let high = Int(stacks.max()!.rounded(.up))

        let missedCount = group.filter { $0.kind == .missedShove }.count
        let dominantKind: PushFoldDeviation.Kind = missedCount * 2 >= group.count ? .missedShove : .overShove

        return DrillFocus(
            position: position,
            stackRange: low...max(low, high),
            dominantKind: dominantKind,
            deviationCount: group.count,
            isTentative: report.pushFoldAdherence.applicableSpots < report.minPushFoldSpotsForConfidence
        )
    }

    /// Deals one drill spot. With probability `focusWeight` (when `focus` is non-nil),
    /// the spot's position and stack are drawn from the focus region; otherwise it's a
    /// fully random spot, same as the plain push/fold trainer.
    public static func spot(
        focus: DrillFocus?,
        focusWeight: Double = defaultFocusWeight,
        using generator: inout RandomNumberGenerator
    ) -> PushFoldSpot {
        guard let focus, Double.random(in: 0..<1, using: &generator) < focusWeight else {
            return PushFoldSpot.random(using: &generator)
        }
        return PushFoldSpot(
            hand: .random(using: &generator),
            position: focus.position,
            effectiveStackBB: Int.random(in: focus.stackRange, using: &generator)
        )
    }

    public static func spot(focus: DrillFocus?, focusWeight: Double = defaultFocusWeight) -> PushFoldSpot {
        var rng: RandomNumberGenerator = SystemRandomNumberGenerator()
        return spot(focus: focus, focusWeight: focusWeight, using: &rng)
    }
}
