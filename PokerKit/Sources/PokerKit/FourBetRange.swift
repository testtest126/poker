import Foundation

public enum FourBetAction: String, Sendable {
    case fourBetValue = "4-Bet (Value)"
    case fourBetBluff = "4-Bet (Bluff)"
    case call = "Call"
    case fold = "Fold"
}

public struct FourBetDecision: Sendable {
    public let action: FourBetAction
    public let handScore: Double
    public let valueThreshold: Double
    public let callThreshold: Double
    public let totalContinuePercentage: Double
    public let fourBetPercentage: Double
    public let isBluffCombo: Bool

    public var reasoning: String {
        let continuePct = String(format: "%.0f", totalContinuePercentage)
        switch action {
        case .fourBetValue:
            return "Hand strength score \(formatted(handScore)) clears the 4-bet-value threshold of "
                + "\(formatted(valueThreshold)) — part of the top \(continuePct)% hero continues with here."
        case .fourBetBluff:
            return "A designated blocker-bluff combo hero also would have opened — "
                + "part of the top \(continuePct)% hero continues with here."
        case .call:
            return "Hand strength score \(formatted(handScore)) clears the calling threshold of "
                + "\(formatted(callThreshold)) but isn't a 4-bet-value hand or a designated bluff combo — "
                + "part of the top \(continuePct)% hero continues with here."
        case .fold:
            return "Hand strength score \(formatted(handScore)) is below the calling threshold of "
                + "\(formatted(callThreshold)) (top \(continuePct)% hero continues with here)."
        }
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}

/// Hero **opened**, got **3-bet**, and now decides fold / call / 4-bet — the one preflop
/// decision point nothing else in this codebase covers. `PushFoldRange`/`OpeningRange` model
/// hero as the first aggressor; `CallingRange`/`ThreeBetRange` model hero reacting to
/// someone else's shove or open. This is hero reacting to someone reacting to *them*.
///
/// **This is this codebase's least-certain preflop model.** Every other model has at least
/// one genuinely-sourced anchor from a dedicated source about that exact situation.
/// `FourBetRange`'s one anchor is a single reported example (a cutoff open facing a button
/// 3-bet, continuing 67% — 50% call, 17% four-bet, folding 33%, found via web search) for
/// *one specific position pairing*, generalized to every other pairing by the same
/// `OpeningRange`-ratio scaling technique used throughout this codebase. Treat every number
/// here as directional, not precise — see `RANGES.md` for the full derivation.
public enum FourBetRange {
    /// The one sourced anchor: cutoff (opener) facing a button 3-bet continues 67% of hands
    /// (50% call + 17% four-bet), assumed ~100bb (the source didn't specify a stack depth —
    /// see `RANGES.md`).
    private static let openerContinueVsAnchor: Double = 67
    private static let fourBetShareOfContinueVsAnchor: Double = 17.0 / 67.0

    /// The anchor pairing itself, so every other spot can be expressed as a ratio against it.
    private static let anchorOpener: Position = .cutoff
    private static let anchorThreeBettor: DefendingPosition = .button

    /// Same blocker-bluff selection `ThreeBetRange` uses — suited wheel aces are the
    /// standard 4-bet bluff too (see `RANGES.md`), for the same reason: they block villain's
    /// AA/AK/KK while keeping real equity if called.
    public static var bluffCombos: Set<String> { ThreeBetRange.bluffCombos }
    private static let bluffPercentageOfCanonicalHands: Double = Double(ThreeBetRange.bluffCombos.count) / 169.0 * 100.0

    /// % of hands hero (the original opener) continues with — call or 4-bet, combined —
    /// facing a 3-bet from `threeBettor`, or `nil` if `threeBettor` couldn't actually be
    /// facing hero's open (they'd have to act before `opener` at an unopened table — the
    /// same `actionOrderIndex` validity check every other defending model in this codebase
    /// uses).
    ///
    /// Scaled by how wide `ThreeBetRange` predicts `threeBettor` is 3-betting `opener` at
    /// this spot, relative to how wide it predicts the anchor pairing 3-bets — a narrower,
    /// more polarized-and-therefore-stronger 3-bettor should see hero continue tighter;
    /// a wider one, looser. Reuses `ThreeBetRange`'s own numbers rather than inventing a
    /// second opinion on 3-bet width.
    public static func totalContinuePercentage(opener: Position, threeBettor: DefendingPosition, effectiveStackBB: Double) -> Double? {
        guard threeBettor.actionOrderIndex > opener.actionOrderIndex else { return nil }

        let anchorThreeBetPercentage = ThreeBetRange.totalThreeBetPercentage(
            defender: anchorThreeBettor, opener: anchorOpener, effectiveStackBB: effectiveStackBB
        ) ?? openerContinueVsAnchor // should never actually be nil (the anchor pairing is always valid), guarded defensively
        let thisThreeBetPercentage = ThreeBetRange.totalThreeBetPercentage(
            defender: threeBettor, opener: opener, effectiveStackBB: effectiveStackBB
        ) ?? anchorThreeBetPercentage

        let ratio = anchorThreeBetPercentage > 0 ? thisThreeBetPercentage / anchorThreeBetPercentage : 1
        return min(max(openerContinueVsAnchor * ratio, 0), 100)
    }

    /// Fold/call/4-bet(value)/4-bet(bluff) decision for `hand`, hero having opened from
    /// `opener` and been 3-bet by `threeBettor`, or `nil` for a nonsensical position pairing.
    ///
    /// Same value/bluff split shape as `ThreeBetRange.decide`: value is the top of `hand`'s
    /// Chen-score ranking sized so value + the fixed bluff list equal
    /// `totalContinuePercentage`'s 4-bet share; bluffs are the fixed suited-wheel-ace list,
    /// included only when `hand` is also within hero's own opening range for `opener` at
    /// this stack (you can't 4-bet-bluff a hand you wouldn't have opened) and
    /// `effectiveStackBB >= 40` — 4-betting needs meaningfully more room behind it than
    /// 3-betting does; shorter than that a "4-bet" is functionally a shove, better modeled by
    /// `PushFoldRange` directly.
    public static func decide(
        hand: HoleCards,
        opener: Position,
        threeBettor: DefendingPosition,
        effectiveStackBB: Double
    ) -> FourBetDecision? {
        guard let totalContinue = totalContinuePercentage(opener: opener, threeBettor: threeBettor, effectiveStackBB: effectiveStackBB) else {
            return nil
        }

        let fourBetPercentage = totalContinue * fourBetShareOfContinueVsAnchor
        let handScore = ChenScore.score(for: hand)

        let wouldHaveOpened = OpeningRange.decide(hand: hand, position: opener, effectiveStackBB: effectiveStackBB).action == .raise

        // Same reasoning as `ThreeBetRange.decide`: a 4-bet range this narrow can be smaller
        // than the fixed bluff carve-out, in which case the honest read is "no bluffs here,"
        // not a shrunken value range — see that function's doc comment for the full rationale.
        let hasRoomForBluffs = fourBetPercentage > bluffPercentageOfCanonicalHands
        let isBluffCombo = hasRoomForBluffs && ThreeBetRange.bluffCombos.contains(hand.notation) && wouldHaveOpened && effectiveStackBB >= 40

        let valuePercentage = hasRoomForBluffs ? fourBetPercentage - bluffPercentageOfCanonicalHands : fourBetPercentage
        let valueThreshold = PushFoldRange.scoreThreshold(forPercentage: valuePercentage)
        let callThreshold = PushFoldRange.scoreThreshold(forPercentage: totalContinue)

        let action: FourBetAction
        if handScore >= valueThreshold {
            action = .fourBetValue
        } else if isBluffCombo {
            action = .fourBetBluff
        } else if handScore >= callThreshold {
            action = .call
        } else {
            action = .fold
        }

        return FourBetDecision(
            action: action,
            handScore: handScore,
            valueThreshold: valueThreshold,
            callThreshold: callThreshold,
            totalContinuePercentage: totalContinue,
            fourBetPercentage: fourBetPercentage,
            isBluffCombo: isBluffCombo
        )
    }
}
