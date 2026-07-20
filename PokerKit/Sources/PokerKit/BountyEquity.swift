import Foundation

/// A bounty-adjusted push/fold decision — see `ai-docs/BOUNTY.md` for the formula, its
/// derivation, and every simplification it makes before trusting a specific number.
public struct BountyAdjustedDecision: Sendable {
    public let action: PushFoldAction
    public let handScore: Double
    public let baseShovePercentage: Double
    public let adjustedShovePercentage: Double
    public let baseScoreThreshold: Double
    public let adjustedScoreThreshold: Double
    public let bountyBB: Double
    public let heroCoversVillain: Bool

    /// Whether the bounty actually changed anything for this spot (a hand can only be
    /// widened *into* the range, never widened out of it — see `BountyEquity`).
    public var bountyChangedTheRange: Bool { adjustedShovePercentage > baseShovePercentage }

    /// A short, human-readable justification that's explicit about whether — and why — a
    /// bounty affected this decision, rather than silently folding the adjustment into
    /// ordinary-looking numbers.
    public var reasoning: String {
        let baseLine = "Hand strength score \(formatted(handScore)) vs. a base (no-bounty) shove "
            + "threshold of \(formatted(baseScoreThreshold)) (top \(pct(baseShovePercentage))% of hands)."

        guard bountyBB > 0 else {
            return baseLine + " No bounty entered."
        }
        guard heroCoversVillain else {
            return baseLine + " A \(formatted(bountyBB))bb bounty is on the table, but hero doesn't "
                + "cover villain here, so it isn't collectible on this shove — no adjustment applied."
        }
        return baseLine + " A \(formatted(bountyBB))bb bounty (hero covers villain) widens the shove "
            + "threshold to \(formatted(adjustedScoreThreshold)) (top \(pct(adjustedShovePercentage))% of hands). "
            + (action == .push ? "This hand shoves." : "Still not enough, even with the bounty.")
    }

    private func pct(_ value: Double) -> String { String(format: "%.0f", value) }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}

/// Converts a PKO bounty into a widening of a **chip-EV** shove/call percentage — see
/// `ai-docs/BOUNTY.md` for the full derivation and its sources.
///
/// **The short version:** winning a hand where hero covers villain doesn't just win the
/// pot, it eliminates villain and claims their bounty — extra equity a pure chip-EV model
/// (`PushFoldRange`) has no way to see, since it only ever reasons about chips. The
/// standard approach found across PKO strategy sources treats the bounty as chips added to
/// what you win, which lowers the equity you need to profitably get in — and, in this
/// model, translates to a *wider* range: `newThreshold = oldThreshold × pot / (pot +
/// bounty)`. This module implements that as a widening ratio (the reciprocal, applied to a
/// percentage rather than a raw equity number) rather than a threshold shrink, so it
/// composes with the rest of this codebase's percentage → `PushFoldRange.scoreThreshold`
/// pipeline instead of inventing a second one.
///
/// **This is an overlay, not a replacement.** It never touches `PushFoldRange` — every
/// function here takes a base percentage as input and returns an adjusted one; `bountyBB ==
/// 0` (or `heroCoversVillain == false`) is defined to be an exact no-op, so the plain
/// chip-EV tool is provably unaffected by this module existing.
///
/// **What this deliberately doesn't model** (see `BOUNTY.md` for the full list): ICM at
/// all, the risk of *being* covered (a separate, negative adjustment this module doesn't
/// compute), future-bounty-overlay / stack-dynamics effects across a whole tournament, and
/// anything about villain's calling range (the bounty math here is symmetric and would
/// apply the same way to a call as to a shove, but only the shove side is wired up — see
/// `BOUNTY.md`'s "Scope" section for why).
public enum BountyEquity {
    /// Converts a bounty quoted as a fraction of the tournament's starting stack (a common
    /// way PKO structures describe bounty size, e.g. "50% of the buy-in funds the bounty
    /// pool, worth ~33% of a starting stack") into bb, given the starting stack size in bb.
    /// Negative inputs are clamped to 0 rather than producing a negative bounty.
    public static func bountyBB(fractionOfStartingStack fraction: Double, startingStackBB: Double) -> Double {
        max(fraction, 0) * max(startingStackBB, 0)
    }

    /// The standard PKO break-even-equity-threshold multiplier, `pot / (pot + bounty)` —
    /// see the module doc comment and `BOUNTY.md` for the source and derivation. Always in
    /// `(0, 1]`: `1` (no change) whenever there's nothing to adjust for (no bounty, hero
    /// doesn't cover villain, or a degenerate zero/negative stack), shrinking toward 0 as
    /// the bounty grows large relative to the pot.
    ///
    /// `potBB` is approximated as `2 × effectiveStackBB` — hero's shove plus a covering
    /// call, ignoring blinds/antes already in the pot. This is a standard simplification
    /// for short-stack push/fold math (blinds/antes are a small fraction of the pot at the
    /// stack depths `PushFoldRange` covers) and matches the fact that `PushFoldRange`
    /// itself never takes blind/ante size as an input either — this module doesn't
    /// introduce a new missing input, it inherits an existing one.
    public static func thresholdMultiplier(effectiveStackBB: Double, bountyBB: Double, heroCoversVillain: Bool) -> Double {
        guard heroCoversVillain, bountyBB > 0, effectiveStackBB > 0 else { return 1 }
        let potBB = 2 * effectiveStackBB
        return potBB / (potBB + bountyBB)
    }

    /// `baseShovePercentage`, widened by the reciprocal of `thresholdMultiplier` and
    /// clamped to 100. Exact no-op (`== baseShovePercentage`) whenever
    /// `thresholdMultiplier` is 1 — in particular, always a no-op when `bountyBB == 0`.
    public static func widenedPercentage(
        baseShovePercentage: Double,
        effectiveStackBB: Double,
        bountyBB: Double,
        heroCoversVillain: Bool
    ) -> Double {
        let multiplier = thresholdMultiplier(effectiveStackBB: effectiveStackBB, bountyBB: bountyBB, heroCoversVillain: heroCoversVillain)
        guard multiplier < 1, multiplier > 0 else { return baseShovePercentage }
        return min(baseShovePercentage / multiplier, 100)
    }

    /// Bounty-adjusted shove/fold decision for `hand`, composing straight through
    /// `PushFoldRange`'s own percentage and threshold functions — this module never
    /// re-derives or duplicates either. `bountyBB: 0` reproduces
    /// `PushFoldRange.decide(hand:position:effectiveStackBB:)` exactly.
    public static func decide(
        hand: HoleCards,
        position: Position,
        effectiveStackBB: Double,
        bountyBB: Double,
        heroCoversVillain: Bool
    ) -> BountyAdjustedDecision {
        let basePercentage = PushFoldRange.shovePercentage(position: position, effectiveStackBB: effectiveStackBB)
        let adjustedPercentage = widenedPercentage(
            baseShovePercentage: basePercentage,
            effectiveStackBB: effectiveStackBB,
            bountyBB: bountyBB,
            heroCoversVillain: heroCoversVillain
        )
        let baseThreshold = PushFoldRange.scoreThreshold(forPercentage: basePercentage)
        let adjustedThreshold = PushFoldRange.scoreThreshold(forPercentage: adjustedPercentage)
        let handScore = ChenScore.score(for: hand)
        let action: PushFoldAction = handScore >= adjustedThreshold ? .push : .fold

        return BountyAdjustedDecision(
            action: action,
            handScore: handScore,
            baseShovePercentage: basePercentage,
            adjustedShovePercentage: adjustedPercentage,
            baseScoreThreshold: baseThreshold,
            adjustedScoreThreshold: adjustedThreshold,
            bountyBB: bountyBB,
            heroCoversVillain: heroCoversVillain
        )
    }
}
