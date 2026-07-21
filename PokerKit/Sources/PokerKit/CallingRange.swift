import Foundation

// MARK: - Defending position

/// Hero's position when **defending** — reacting to another player's shove or open —
/// rather than acting first. Distinct from `Position` because a defending hero can be the
/// big blind, which `Position` deliberately excludes (see its doc comment): the big blind
/// never opens or shoves into an unopened pot, but is exactly who most often *calls* one.
///
/// Cases are declared in the same order as `Position` (UTG...SB) with `.bigBlind` appended,
/// so each case's index in `allCases` doubles as its action-order seat at an unopened
/// table. `CallingRange` uses that ordering to reject nonsensical combinations — a
/// position can't defend against a shove or open from a position that acts *after* it.
public enum DefendingPosition: String, CaseIterable, Identifiable, Sendable {
    case utg = "UTG"
    case middlePosition = "MP"
    case hijack = "HJ"
    case cutoff = "CO"
    case button = "BTN"
    case smallBlind = "SB"
    case bigBlind = "BB"

    public var id: String { rawValue }

    public var fullName: String {
        switch self {
        case .utg: return "Under the Gun"
        case .middlePosition: return "Middle Position"
        case .hijack: return "Hijack"
        case .cutoff: return "Cutoff"
        case .button: return "Button"
        case .smallBlind: return "Small Blind"
        case .bigBlind: return "Big Blind"
        }
    }

    /// This position's seat index in the standard UTG-to-BB action order.
    public var actionOrderIndex: Int { Self.allCases.firstIndex(of: self)! }
}

extension Position {
    /// This position's seat index in the standard UTG-to-BB action order — comparable
    /// directly with `DefendingPosition.actionOrderIndex` since both enums declare their
    /// shared six cases (UTG...SB) in identical order.
    public var actionOrderIndex: Int { Self.allCases.firstIndex(of: self)! }
}

// MARK: - Facing a shove

public enum CallVsShoveAction: String, Sendable {
    case call = "Call"
    case fold = "Fold"
}

public struct CallVsShoveDecision: Sendable {
    public let action: CallVsShoveAction
    public let handScore: Double
    public let scoreThreshold: Double
    public let callPercentage: Double

    public var reasoning: String {
        let pct = String(format: "%.0f", callPercentage)
        switch action {
        case .call:
            return "Hand strength score \(formatted(handScore)) clears the calling threshold of "
                + "\(formatted(scoreThreshold)) (top \(pct)% of hands) for this stack and position."
        case .fold:
            return "Hand strength score \(formatted(handScore)) is below the calling threshold of "
                + "\(formatted(scoreThreshold)) (top \(pct)% of hands) for this stack and position."
        }
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}

// MARK: - Facing an open

public enum OpenDefenseAction: String, Sendable {
    case threeBet = "3-Bet"
    case call = "Call"
    case fold = "Fold"
}

public struct OpenDefenseDecision: Sendable {
    public let action: OpenDefenseAction
    public let handScore: Double
    public let threeBetThreshold: Double
    public let callThreshold: Double
    public let totalDefensePercentage: Double
    public let threeBetPercentage: Double

    public var reasoning: String {
        let defendPct = String(format: "%.0f", totalDefensePercentage)
        switch action {
        case .threeBet:
            return "Hand strength score \(formatted(handScore)) clears the 3-bet threshold of "
                + "\(formatted(threeBetThreshold)) — part of the top \(defendPct)% this spot defends."
        case .call:
            return "Hand strength score \(formatted(handScore)) clears the calling threshold of "
                + "\(formatted(callThreshold)) but not the 3-bet threshold of \(formatted(threeBetThreshold)) — "
                + "part of the top \(defendPct)% this spot defends."
        case .fold:
            return "Hand strength score \(formatted(handScore)) is below the calling threshold of "
                + "\(formatted(callThreshold)) (top \(defendPct)% this spot defends)."
        }
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}

/// Defense models for the two situations `PushFoldRange` and `OpeningRange` don't cover:
/// hero **reacting** to someone else's shove or open, rather than acting first.
///
/// **This is a hand-tuned study aid, not solver output** — same posture as `PushFoldRange`
/// and `OpeningRange`, and considerably less certain than either. Real defending ranges
/// (especially multi-way, ICM-weighted ones) come from solvers or ICM calculators that
/// account for exact stacks, payouts, and every opponent's tendencies. See `RANGES.md` for
/// the full source basis of every number here — in short:
///
/// - **Facing a shove, big blind calling** is the best-grounded case: it's the one
///   situation with a widely-published Nash equivalent (heads-up SB-shoves/BB-calls).
/// - **Facing a shove, small blind or a non-blind caller** and **facing an open from any
///   position** are meaningfully less certain — derived from documented qualitative
///   principles (calling needs real equity so is tighter than shoving; blind defense is
///   wide and gets wider late; small blind is more fold-or-3-bet than big blind) rather
///   than a position-by-position sourced chart, because no such chart is publicly
///   available for anything beyond the pure heads-up case. Treat every number outside
///   "BB facing a shove" as directional, not precise.
///
/// Both models reuse `ChenScore` for hand ranking and `PushFoldRange.scoreThreshold` for
/// turning a percentage into a score cutoff — still the only hand-ranking pipeline in this
/// codebase. Neither model invents a new one.
public enum CallingRange {
    // MARK: Facing a shove

    /// Same ten stack breakpoints as `PushFoldRange`, since this model's percentages are
    /// discounts *off* `PushFoldRange`'s own shove percentages (see below).
    private static let shoveDiscountBreakpoints: [Double] = [1, 2, 3, 5, 7, 10, 12, 15, 17, 20]

    /// Fraction of the shover's own `PushFoldRange` shove-percentage that's a profitable
    /// call, aligned 1:1 with `shoveDiscountBreakpoints`. Calling always requires more
    /// equity than shoving (the caller faces a real range instead of just buying fold
    /// equity), so this is always < 1, and the gap narrows as the stack shortens — both
    /// documented, widely-repeated qualitative facts. The specific curve is a hand-tuned
    /// approximation calibrated against the one concrete external data point found: a
    /// published heads-up Nash SB-shove figure of ~50% at 10bb, compared against this
    /// project's own `PushFoldRange` SB shove figure of 58% at 10bb (close enough to treat
    /// as the same phenomenon in a 6-max-context table). See RANGES.md.
    private static let shoveDiscountByStack: [Double] = [0.90, 0.82, 0.75, 0.65, 0.58, 0.52, 0.48, 0.44, 0.41, 0.38]

    /// Further discount applied for callers other than the big blind. The big blind is the
    /// only calling position with a genuine Nash equivalent (it closes the action, so a
    /// shove reaching it is, in effect, the heads-up case); every other caller either has a
    /// worse price (small blind posted half a blind, not a full one) or risks a player still
    /// left to act waking up behind them (squeeze risk) — both reasons real defending ranges
    /// there are narrower, but neither is quantified by any source found. These numbers are
    /// this model's least-confident part. `.utg` is included only for dictionary
    /// completeness — it can never actually be a valid caller (nobody acts before UTG).
    private static let callerPositionDiscount: [DefendingPosition: Double] = [
        .bigBlind: 1.0,
        .smallBlind: 0.75,
        .button: 0.55,
        .cutoff: 0.5,
        .hijack: 0.45,
        .middlePosition: 0.4,
        .utg: 0.35,
    ]

    private static func shoveDiscount(effectiveStackBB: Double) -> Double {
        let stack = min(max(effectiveStackBB, shoveDiscountBreakpoints.first!), shoveDiscountBreakpoints.last!)

        guard let upperIndex = shoveDiscountBreakpoints.firstIndex(where: { $0 >= stack }) else {
            return shoveDiscountByStack.last!
        }
        if shoveDiscountBreakpoints[upperIndex] == stack || upperIndex == 0 {
            return shoveDiscountByStack[upperIndex]
        }

        let lowerIndex = upperIndex - 1
        let lowerBB = shoveDiscountBreakpoints[lowerIndex]
        let upperBB = shoveDiscountBreakpoints[upperIndex]
        let fraction = (stack - lowerBB) / (upperBB - lowerBB)
        return shoveDiscountByStack[lowerIndex] + fraction * (shoveDiscountByStack[upperIndex] - shoveDiscountByStack[lowerIndex])
    }

    /// % of hands it's profitable for `caller` to call a shove from `shover`, or `nil` if
    /// `caller` couldn't actually be facing that shove (they'd have to act before `shover`
    /// at an unopened table).
    public static func callPercentage(caller: DefendingPosition, shover: Position, effectiveStackBB: Double) -> Double? {
        guard caller.actionOrderIndex > shover.actionOrderIndex else { return nil }
        let shovePercentage = PushFoldRange.shovePercentage(position: shover, effectiveStackBB: effectiveStackBB)
        let discount = shoveDiscount(effectiveStackBB: effectiveStackBB) * callerPositionDiscount[caller]!
        return min(max(shovePercentage * discount, 0), 100)
    }

    /// Call/fold decision for `hand` when `caller` is facing an all-in shove from `shover`
    /// at `effectiveStackBB`, or `nil` for a nonsensical position pairing (see
    /// `callPercentage`).
    public static func decideVsShove(
        hand: HoleCards,
        caller: DefendingPosition,
        shover: Position,
        effectiveStackBB: Double
    ) -> CallVsShoveDecision? {
        guard let percentage = callPercentage(caller: caller, shover: shover, effectiveStackBB: effectiveStackBB) else {
            return nil
        }
        let threshold = PushFoldRange.scoreThreshold(forPercentage: percentage)
        let handScore = ChenScore.score(for: hand)
        let action: CallVsShoveAction = handScore >= threshold ? .call : .fold
        return CallVsShoveDecision(action: action, handScore: handScore, scoreThreshold: threshold, callPercentage: percentage)
    }

    // MARK: Facing an open

    /// Big blind's combined call+3-bet continuing frequency against a button open —
    /// sourced (see RANGES.md): a commonly-cited combined-defense figure of ~84% for BB vs
    /// a standard-sized button open. This is the model's one external anchor; every other
    /// position/opener combination below scales off it.
    private static let bigBlindDefenseVsButton: Double = 84

    /// Small blind's total defense as a fraction of what the big blind would defend against
    /// the same open — small blind gets a worse price (half a blind posted, not a full
    /// one) and is out of position for the rest of the hand against everyone except the
    /// button, so real small-blind ranges are consistently narrower than big-blind ranges
    /// in every source found, though none gives an exact ratio. Hand-tuned.
    private static let smallBlindDefenseFactor: Double = 0.65

    /// Total defense for a non-blind defender (someone still to act behind the opener, not
    /// in the blinds — e.g. the cutoff facing an under-the-gun open) as a fraction of what
    /// the big blind would defend against the same open. No position-by-position source was
    /// found for this case at all, unlike blind defense; this single flat factor is the
    /// least-confident number in this entire model. Treat it as a rough placeholder, not a
    /// considered chart.
    private static let nonBlindDefenseFactor: Double = 0.5

    /// Share of total defense that goes to 3-betting rather than flatting. The small blind
    /// is documented as leaning harder toward 3-bet-or-fold (avoiding cold-calls, which are
    /// weak out of position against a raise) than the big blind; non-blind defenders are
    /// assumed in between. All three numbers are hand-tuned, not sourced — see RANGES.md.
    /// A real 3-betting range is polarized (strong hands *and* bluffs); ranking purely by
    /// Chen score only captures the value end of that, never the bluffing combos — a
    /// deliberate, disclosed simplification.
    private static func threeBetShare(of defender: DefendingPosition) -> Double {
        switch defender {
        case .bigBlind: return 0.25
        case .smallBlind: return 0.45
        default: return 0.35
        }
    }

    /// % of hands `defender` should continue with (call or 3-bet, combined) against an open
    /// from `opener`, or `nil` if `defender` couldn't actually be facing that open (they'd
    /// have to act before `opener` at an unopened table).
    public static func totalDefensePercentage(defender: DefendingPosition, opener: Position, effectiveStackBB: Double) -> Double? {
        guard defender.actionOrderIndex > opener.actionOrderIndex else { return nil }

        let openerOpenPercentage = OpeningRange.openPercentage(position: opener, effectiveStackBB: effectiveStackBB)
        let buttonOpenPercentage = OpeningRange.openPercentage(position: .button, effectiveStackBB: effectiveStackBB)
        let bigBlindDefense = bigBlindDefenseVsButton * (openerOpenPercentage / buttonOpenPercentage)

        let factor: Double
        switch defender {
        case .bigBlind: factor = 1.0
        case .smallBlind: factor = smallBlindDefenseFactor
        default: factor = nonBlindDefenseFactor
        }
        return min(max(bigBlindDefense * factor, 0), 100)
    }

    /// Fold/call/3-bet decision for `hand` when `defender` is facing an open-raise from
    /// `opener` at `effectiveStackBB`, or `nil` for a nonsensical position pairing (see
    /// `totalDefensePercentage`).
    public static func decideVsOpen(
        hand: HoleCards,
        defender: DefendingPosition,
        opener: Position,
        effectiveStackBB: Double
    ) -> OpenDefenseDecision? {
        guard let totalDefense = totalDefensePercentage(defender: defender, opener: opener, effectiveStackBB: effectiveStackBB) else {
            return nil
        }
        let threeBetPercentage = totalDefense * threeBetShare(of: defender)
        let callThreshold = PushFoldRange.scoreThreshold(forPercentage: totalDefense)
        let threeBetThreshold = PushFoldRange.scoreThreshold(forPercentage: threeBetPercentage)
        let handScore = ChenScore.score(for: hand)

        let action: OpenDefenseAction
        if handScore >= threeBetThreshold {
            action = .threeBet
        } else if handScore >= callThreshold {
            action = .call
        } else {
            action = .fold
        }

        return OpenDefenseDecision(
            action: action,
            handScore: handScore,
            threeBetThreshold: threeBetThreshold,
            callThreshold: callThreshold,
            totalDefensePercentage: totalDefense,
            threeBetPercentage: threeBetPercentage
        )
    }
}
