import Foundation

public enum ThreeBetAction: String, Sendable {
    case threeBetValue = "3-Bet (Value)"
    case threeBetBluff = "3-Bet (Bluff)"
    case call = "Call"
    case fold = "Fold"
}

public struct ThreeBetDecision: Sendable {
    public let action: ThreeBetAction
    public let handScore: Double
    public let valueThreshold: Double
    public let callThreshold: Double
    public let totalDefensePercentage: Double
    public let threeBetPercentage: Double
    public let isBluffCombo: Bool

    public var reasoning: String {
        let defendPct = String(format: "%.0f", totalDefensePercentage)
        switch action {
        case .threeBetValue:
            return "Hand strength score \(formatted(handScore)) clears the 3-bet-value threshold of "
                + "\(formatted(valueThreshold)) — part of the top \(defendPct)% this spot defends."
        case .threeBetBluff:
            return "A designated blocker-bluff combo (not a raw hand-strength threshold) — "
                + "part of the top \(defendPct)% this spot defends."
        case .call:
            return "Hand strength score \(formatted(handScore)) clears the calling threshold of "
                + "\(formatted(callThreshold)) but isn't a 3-bet-value hand or a designated bluff combo — "
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

/// A dedicated, more carefully-sourced model of the **3-betting** slice of facing an open —
/// `CallingRange.decideVsOpen` already produces a fold/call/3-bet decision, but its 3-bet
/// split is a flat, undifferentiated top-slice of Chen score (25%/45%/35% of total defense
/// by position — see `RANGES.md`), which can't represent what a real 3-bet range actually
/// looks like: **polarized**, built from premium value hands *and* a distinct set of
/// blocker-driven bluffs, not a single contiguous slice of "hand strength."
///
/// **This module is not a replacement for `CallingRange`** — `CallingRange.decideVsOpen`
/// is unchanged, still backs the existing "Facing Open" grid mode, and its own tests still
/// pass with its own numbers. `ThreeBetRange` is a second, more detailed opinion
/// specifically for players studying 3-bet/4-bet strategy, and the two *will* disagree on
/// a given spot's 3-bet percentage — see `RANGES.md`'s "Two opinions, on purpose" section
/// for exactly how much and why that's a disclosed choice, not an inconsistency to silently
/// paper over.
///
/// **This is a hand-tuned study aid, not solver output** — same posture as every other
/// model in this codebase, and see "Source basis" in `RANGES.md` for exactly what's sourced
/// (one external anchor) vs. hand-tuned (everything else, clearly flagged).
public enum ThreeBetRange {
    /// Big blind's 3-bet percentage against a button open at ~100bb — sourced (see
    /// `RANGES.md`): commonly cited in the 12-14% range for a polarized 100bb 3-bet. This
    /// project's own anchor is the midpoint, 13%. This is the model's one external anchor;
    /// every other position/opener/stack combination scales off it via the same
    /// `OpeningRange`-ratio technique `CallingRange.totalDefensePercentage` already uses.
    private static let bigBlindThreeBetVsButton: Double = 13

    /// Same position-based scaling factors `CallingRange.totalDefensePercentage` uses for
    /// its own total-defense figure, reused here rather than inventing a second opinion on
    /// "how much narrower is the small blind / a non-blind defender than the big blind."
    private static let smallBlindFactor: Double = 0.65
    private static let nonBlindFactor: Double = 0.5

    /// The standard, most-consistently-cited 3-bet **blocker bluff** selection across MTT
    /// strategy sources found while building this (upswingpoker.com, tournamentpokeredge.com,
    /// bbzpoker.com — see `RANGES.md`): suited wheel aces, A5s down to A2s. These block
    /// villain's premium pairs and AK while retaining real equity when called — the standard
    /// justification for 3-bet bluffing with them rather than, say, a middling offsuit
    /// broadway that blocks less and plays worse out of position.
    ///
    /// **Deliberately not scaled by stack or position** — real 3-bet bluff selection is
    /// chosen for blocker properties, a different axis than the raw hand-strength percentile
    /// this codebase's threshold pipeline otherwise uses everywhere else. Unlike every
    /// percentage in this file, this list doesn't shrink or grow with the spot; only whether
    /// it's included at all does (see `decide`'s stack-depth guard below).
    public static let bluffCombos: Set<String> = ["A5s", "A4s", "A3s", "A2s"]

    /// % of the 169 canonical hands `bluffCombos` represents — used to back the value
    /// threshold out of the total 3-bet percentage (see `decide`).
    private static let bluffPercentageOfCanonicalHands: Double = Double(bluffCombos.count) / 169.0 * 100.0

    /// % of hands `defender` should 3-bet (value + bluff combined) against an open from
    /// `opener`, or `nil` for a nonsensical position pairing (see `CallingRange`'s
    /// `actionOrderIndex` validity check, reused identically here).
    public static func totalThreeBetPercentage(defender: DefendingPosition, opener: Position, effectiveStackBB: Double) -> Double? {
        guard defender.actionOrderIndex > opener.actionOrderIndex else { return nil }

        let openerOpenPercentage = OpeningRange.openPercentage(position: opener, effectiveStackBB: effectiveStackBB)
        let buttonOpenPercentage = OpeningRange.openPercentage(position: .button, effectiveStackBB: effectiveStackBB)
        let bigBlindThreeBet = bigBlindThreeBetVsButton * (openerOpenPercentage / buttonOpenPercentage)

        let factor: Double
        switch defender {
        case .bigBlind: factor = 1.0
        case .smallBlind: factor = smallBlindFactor
        default: factor = nonBlindFactor
        }
        return min(max(bigBlindThreeBet * factor, 0), 100)
    }

    /// Fold/call/3-bet(value)/3-bet(bluff) decision for `hand`, or `nil` for a nonsensical
    /// position pairing.
    ///
    /// The 3-bet range is built from two independent pieces, not one contiguous slice:
    /// - **Value**: the top of `hand`'s Chen-score ranking, sized so that value + the fixed
    ///   bluff-combo list together equal `totalThreeBetPercentage` — i.e. the bluffs are
    ///   *carved out of*, not added on top of, the sourced total.
    /// - **Bluff**: exactly `bluffCombos`, included whenever the spot is valid and
    ///   `effectiveStackBB >= 20` (3-bet bluffing needs enough stack behind it to fold out a
    ///   real range and still play a pot if called; shorter than that, this codebase's
    ///   short-stack tools — `PushFoldRange`/`CallingRange.decideVsShove` — are the better
    ///   model for the spot anyway).
    ///
    /// Reuses `CallingRange.totalDefensePercentage` as the outer call-or-better boundary
    /// (still the one existing opinion on "how wide overall does this spot defend") — this
    /// module only refines what's *inside* that boundary.
    public static func decide(
        hand: HoleCards,
        defender: DefendingPosition,
        opener: Position,
        effectiveStackBB: Double
    ) -> ThreeBetDecision? {
        guard let threeBetTotal = totalThreeBetPercentage(defender: defender, opener: opener, effectiveStackBB: effectiveStackBB) else {
            return nil
        }
        guard let totalDefense = CallingRange.totalDefensePercentage(defender: defender, opener: opener, effectiveStackBB: effectiveStackBB) else {
            return nil
        }

        let handScore = ChenScore.score(for: hand)

        // A spot this narrow (e.g. a non-blind defender vs. a tight UTG open) can have a
        // total 3-bet percentage *smaller* than the fixed bluff-combo carve-out below — real
        // advice for a spot that tight is "just value, no bluffs" (see `bluffCombos`'s doc
        // comment's sources), not "shrink value to make room." Bluffs are only carved out
        // when there's genuine room for them; otherwise the whole total is value, and
        // `PushFoldRange.scoreThreshold` already guarantees at least the single best hand
        // (AA) clears the value threshold even at very small percentages — no separate
        // "is there a value range at all" guard is needed here.
        let hasRoomForBluffs = threeBetTotal > bluffPercentageOfCanonicalHands
        let isBluffCombo = hasRoomForBluffs && bluffCombos.contains(hand.notation) && effectiveStackBB >= 20

        let valuePercentage = hasRoomForBluffs ? threeBetTotal - bluffPercentageOfCanonicalHands : threeBetTotal
        let valueThreshold = PushFoldRange.scoreThreshold(forPercentage: valuePercentage)
        let callThreshold = PushFoldRange.scoreThreshold(forPercentage: max(totalDefense, threeBetTotal))

        let action: ThreeBetAction
        if handScore >= valueThreshold {
            action = .threeBetValue
        } else if isBluffCombo {
            action = .threeBetBluff
        } else if handScore >= callThreshold {
            action = .call
        } else {
            action = .fold
        }

        return ThreeBetDecision(
            action: action,
            handScore: handScore,
            valueThreshold: valueThreshold,
            callThreshold: callThreshold,
            totalDefensePercentage: totalDefense,
            threeBetPercentage: threeBetTotal,
            isBluffCombo: isBluffCombo
        )
    }
}
