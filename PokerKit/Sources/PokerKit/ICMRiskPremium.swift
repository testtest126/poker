import Foundation

/// How much tighter an all-in **call** should be than pure chip-EV suggests once ICM is
/// accounted for — the standard "ICM makes calling shoves tighter near the bubble/final
/// table" effect. See `ai-docs/ICM.md`'s "ICM risk premium" section for the derivation and
/// every simplification below, spelled out.
///
/// **This is an adjustment layer, not a replacement.** It never touches `ICM`,
/// `PushFoldRange`, or `CallingRange` — it's a separate, additive opinion computed from
/// `ICM.equities` that a caller can consult alongside (not instead of) the existing chip-EV
/// calling models, the same "overlay, not mutation" shape `BountyEquity` already uses for
/// PKO bounties.
///
/// **What this deliberately simplifies away** (all flagged here rather than silently
/// assumed):
/// - **A single all-in confrontation for full stacks.** Models exactly one hero-vs-villain
///   shove/call where the loser is fully eliminated and the winner absorbs the loser's
///   entire stack (a "double up or bust" spot) — no side pots, no partial/covering stacks,
///   no multi-way all-ins.
/// - **Busting means $0, not a guaranteed min-cash.** A player who loses the confrontation
///   is assumed to win nothing further, even if they were already itm and a real
///   tournament would still pay them the min-cash for whatever place they bust in. This is
///   the standard simplifying assumption introductory ICM risk-premium explanations use; it
///   slightly *overstates* the true risk premium (the real gap between chip-EV and ICM is a
///   little smaller than this model reports, since a real bust often isn't worth literally
///   $0). Getting this exactly right requires knowing the full remaining payout ladder and
///   how many total entrants have already busted — information this module doesn't have and
///   doesn't ask for.
/// - **No Future Game State (FGS).** Doesn't model that winning a confrontation also
///   improves hero's *position* for hands after this one (better `PushFoldRange`/etc. odds
///   from a bigger stack) — only this single all-in's direct $EV.
/// - **`otherStacks` is treated as the entire remaining field.** If there are players alive
///   elsewhere in the tournament not included in `otherStacks`, the computed premium is
///   wrong — this is a final-table/complete-remaining-field tool, matching `ICM.equities`'s
///   own scope.
public enum ICMRiskPremium {
    /// A single all-in confrontation's ICM cost/benefit breakdown. All equities are in the
    /// same currency units as the `payouts` passed to `assess`.
    public struct Assessment: Sendable {
        /// The win probability at which calling breaks even in pure chip terms, ignoring
        /// ICM entirely: `heroStack / (heroStack + villainStack)`. Independent of `payouts`
        /// or `otherStacks` — a pot-odds number, not a tournament-equity one.
        public let chipEVRequiredEquity: Double
        /// The win probability at which calling breaks even in ICM ($) terms. `.nan` if
        /// `payouts` has no positive value to play for (nothing to compute a premium
        /// against).
        public let icmRequiredEquity: Double
        /// `icmRequiredEquity - chipEVRequiredEquity` — how much *extra* win probability ICM
        /// demands before calling is profitable. Positive in the standard "protect your
        /// stack near a payout jump" case; can be at or near zero when there's no payout
        /// jump to protect (see `ai-docs/ICM.md`).
        public let riskPremium: Double
        /// Hero's ICM equity if this confrontation never happens (stacks unchanged).
        public let foldEquity: Double
        /// Hero's ICM equity if hero wins (absorbs villain's stack; villain is removed from
        /// the field).
        public let winEquity: Double
        /// Hero's ICM equity if hero loses — fixed at `0` (see the module doc comment's
        /// "busting means $0" simplification).
        public let loseEquity: Double

        public var reasoning: String {
            guard icmRequiredEquity.isFinite else {
                return "No payout to compute an ICM premium against (payouts sum to $0)."
            }
            let chip = String(format: "%.1f", chipEVRequiredEquity * 100)
            let icm = String(format: "%.1f", icmRequiredEquity * 100)
            let premium = String(format: "%.1f", riskPremium * 100)
            return "Chip-EV breakeven: \(chip)% equity. ICM breakeven: \(icm)% equity "
                + "(a \(premium)-point risk premium from tournament payout pressure)."
        }
    }

    /// ICM-adjusted call/fold breakeven for hero facing a `villainStack`-sized all-in, with
    /// `otherStacks` (everyone else still alive in the tournament) unaffected by the
    /// outcome. See the module doc comment for every assumption this makes.
    public static func assess(
        heroStack: Double,
        villainStack: Double,
        otherStacks: [Double],
        payouts: [Double]
    ) -> Assessment {
        precondition(heroStack > 0 && villainStack > 0, "Both hero and villain need a positive stack to be in a confrontation at all.")
        precondition(otherStacks.allSatisfy { $0 > 0 }, "otherStacks must not include already-busted (0-chip) players — omit them instead.")

        let chipEVRequired = heroStack / (heroStack + villainStack)

        let foldStacks = [heroStack, villainStack] + otherStacks
        let foldEquity = ICM.equities(stacks: foldStacks, payouts: payouts)[0]

        let winStacks = [heroStack + villainStack] + otherStacks
        let winEquity = ICM.equities(stacks: winStacks, payouts: payouts)[0]

        let loseEquity = 0.0

        let icmRequired: Double = (winEquity - loseEquity) > 0
            ? (foldEquity - loseEquity) / (winEquity - loseEquity)
            : .nan

        return Assessment(
            chipEVRequiredEquity: chipEVRequired,
            icmRequiredEquity: icmRequired,
            riskPremium: icmRequired - chipEVRequired,
            foldEquity: foldEquity,
            winEquity: winEquity,
            loseEquity: loseEquity
        )
    }
}
