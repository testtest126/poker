import Foundation

/// The **Independent Chip Model** (a.k.a. the Malmuth-Harville method) — converts a set of
/// tournament chip stacks and a payout structure into each player's exact $EV, accounting
/// for the fact that chips aren't linearly worth cash once a payout jump is on the table
/// (doubling up doesn't double your $EV; busting doesn't cost you your whole stack's $ value
/// if you were already guaranteed a min-cash). See `ai-docs/ICM.md` for the full derivation,
/// worked examples validated against a published source, and this model's scope.
///
/// **This is exact math, not a heuristic** — unlike every push/fold/opening/3-bet/4-bet
/// model elsewhere in this codebase, there's no hand-tuned percentage table here. Given
/// stacks and a payout structure, ICM equity is a specific, computable number; this module
/// computes it exactly (to floating-point precision), not an approximation of it.
public enum ICM {
    /// Each player's exact ICM $ equity for the given `stacks` and `payouts`.
    ///
    /// `payouts` is ordered 1st-place-first; a finishing position beyond
    /// `payouts.count` (i.e. finishing out of the money) pays $0. `stacks` must all be
    /// strictly positive — a player with 0 chips has already busted and isn't part of this
    /// model's field; see `ICMRiskPremium` for how a bust is represented (removing the
    /// player from the array entirely, not zeroing their stack).
    ///
    /// **The algorithm** (Malmuth-Harville): P(a given player finishes 1st) is their share
    /// of total remaining chips. Conditional on who finished 1st, P(a given remaining player
    /// finishes 2nd) is *their* share of the chips remaining *after removing the 1st-place
    /// finisher* — and so on recursively for every subsequent place. A seat's equity is the
    /// sum, over every finishing position, of P(finish in that position) × that position's
    /// payout.
    ///
    /// **Implementation note:** computed via bitmask memoization over "which players are
    /// still uneliminated at this point in the recursion" rather than literally enumerating
    /// every one of the `n!` finishing orders the definition above suggests — the same exact
    /// math (every finishing order is still implicitly weighted correctly), just sharing
    /// work across orders that pass through the same remaining-player set. `O(2^n × n²)`
    /// instead of `O(n!)`: trivial for realistic final-table sizes (≤10 players is instant;
    /// even 20 players — far beyond any real final table — is still sub-second). Not
    /// designed for, and not meaningfully useful at, full-field sizes (hundreds of players);
    /// this is a final-table/bubble tool, not a whole-tournament simulator.
    public static func equities(stacks: [Double], payouts: [Double]) -> [Double] {
        let n = stacks.count
        guard n > 0 else { return [] }
        precondition(stacks.allSatisfy { $0 > 0 }, "ICM.equities requires every stack to be > 0 — a busted (0-chip) player isn't part of the field; remove them instead of zeroing their stack.")

        func payout(atPosition position: Int) -> Double {
            position < payouts.count ? payouts[position] : 0
        }

        var memo: [Int: [Double]] = [:]

        func solve(_ remainingMask: Int) -> [Double] {
            guard remainingMask != 0 else { return Array(repeating: 0, count: n) }
            if let cached = memo[remainingMask] { return cached }

            let position = n - remainingMask.nonzeroBitCount
            var remainingStackSum = 0.0
            for i in 0..<n where remainingMask & (1 << i) != 0 {
                remainingStackSum += stacks[i]
            }

            var result = Array(repeating: 0.0, count: n)
            for i in 0..<n where remainingMask & (1 << i) != 0 {
                let pNext = stacks[i] / remainingStackSum
                let sub = solve(remainingMask & ~(1 << i))
                for p in 0..<n {
                    result[p] += pNext * sub[p]
                }
                result[i] += pNext * payout(atPosition: position)
            }

            memo[remainingMask] = result
            return result
        }

        return solve((1 << n) - 1)
    }
}
