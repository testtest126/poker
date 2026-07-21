import Foundation

/// The result of an equity calculation between two sides (hero vs. villain) — a single
/// hand, or a range of hands, on either side. `winRate + tieRate + loseRate` always sums to
/// (within floating-point rounding) `1.0`.
public struct EquityResult: Sendable {
    /// Fraction of trials hero's hand strictly beats villain's, `0...1`.
    public let winRate: Double
    /// Fraction of trials hero's and villain's hands are exactly equal (chops the pot).
    public let tieRate: Double
    /// Fraction of trials villain's hand strictly beats hero's.
    public let loseRate: Double
    /// How many board completions (exact) or sampled scenarios (Monte Carlo) this result is
    /// based on.
    public let trials: Int
    /// `true` for `Equity.headsUp` (full enumeration — an exact answer, not an estimate).
    /// `false` for `Equity.monteCarlo`/`handVsRange`/`rangeVsRange` (a sampled estimate;
    /// see `EQUITY.md` for the standard-error math behind its documented tolerance).
    public let isExact: Bool
}

/// A minimal, fully deterministic pseudorandom generator (SplitMix64 — Vigna's public-domain
/// algorithm) used only so `Equity.monteCarlo` can be seeded for reproducible test results.
/// Not cryptographically secure, and not meant to be — equity sampling has no such
/// requirement, and a well-known, easily-reimplemented algorithm is preferable here to an
/// opaque one precisely because reproducibility depends on it.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Win/tie/lose equity between two hands or ranges, built entirely on `HandEvaluator` — no
/// shortcuts, no precomputed equity tables. See `ai-docs/EQUITY.md` for the ground-truth
/// numbers this is validated against and this file's performance characteristics.
///
/// Two calculation modes, matching the two situations that actually differ in what's
/// tractable:
///
/// - **`headsUp`** — one hand vs. one hand, **exact**: enumerates every possible completion
///   of the board (all remaining 5-card boards preflop, fewer postflop) and evaluates each
///   one. Always tractable for a fixed pair of hands — worst case (preflop, empty board) is
///   `C(48, 5) = 1,712,304` boards, large but finite, no sampling error at all.
/// - **`monteCarlo`** (and its `handVsRange`/`rangeVsRange` convenience wrappers) — either
///   side can be a *range* (multiple possible hands), which exact enumeration can't handle
///   at any real range width (range × range × board-completions blows up fast). Uses a
///   **fixed-seed** deterministic sample instead, so the same call always returns the same
///   number — `swift test` never flakes on equity.
public enum Equity {
    static let fullDeck: [Card] = Rank.allCases.flatMap { rank in Suit.allCases.map { Card(rank: rank, suit: $0) } }

    /// Default sample size for Monte Carlo calls that don't specify one. `1/sqrt(50_000) ≈
    /// 0.45%` standard error, i.e. roughly `±0.9%` at a 95% confidence interval — see
    /// `EQUITY.md` for why this default was picked and how it was verified in practice.
    public static let defaultMonteCarloIterations = 50_000

    /// Fixed default seed so callers who don't pass one still get fully reproducible
    /// results. Not a "real" secret — deliberately a memorable, obviously-fixed constant.
    public static let defaultSeed: UInt64 = 0xC0FFEE

    // MARK: - Exact: hand vs. hand

    /// Exact win/tie/lose equity for `hero` vs. `villain`, given zero or more known board
    /// cards (0 = preflop, 3 = flop dealt, 4 = turn dealt, 5 = river dealt — though any
    /// count 0...5 is accepted). Enumerates every possible completion of the remaining board
    /// exhaustively; the result has no sampling error.
    ///
    /// - Precondition: `hero`, `villain`, and `board` share no cards (a card can't be both
    ///   in a hole-card hand and on the board, or in both hands).
    public static func headsUp(hero: HoleCards, villain: HoleCards, board: [Card] = []) -> EquityResult {
        let known = [hero.first, hero.second, villain.first, villain.second] + board
        precondition(Set(known).count == known.count, "hero/villain/board share a card")
        precondition(board.count <= 5, "board can have at most 5 cards")

        let usedSet = Set(known)
        let remaining = fullDeck.filter { !usedSet.contains($0) }
        let needed = 5 - board.count

        var wins = 0, ties = 0, losses = 0, total = 0
        var current: [Card] = []
        current.reserveCapacity(needed)

        forEachCombination(of: remaining, choose: needed, current: &current) { drawn in
            let fullBoard = board + drawn
            let heroHand = HandEvaluator.bestHand(from: [hero.first, hero.second] + fullBoard)
            let villainHand = HandEvaluator.bestHand(from: [villain.first, villain.second] + fullBoard)
            total += 1
            if heroHand > villainHand { wins += 1 }
            else if heroHand == villainHand { ties += 1 }
            else { losses += 1 }
        }

        return EquityResult(
            winRate: Double(wins) / Double(total),
            tieRate: Double(ties) / Double(total),
            loseRate: Double(losses) / Double(total),
            trials: total,
            isExact: true
        )
    }

    // MARK: - Monte Carlo: hand/range vs. hand/range

    /// Fixed-seed Monte Carlo win/tie/lose equity for a hand (or range of hands) on each
    /// side, given zero or more known board cards. Each trial samples one concrete hand
    /// uniformly from `hero`, one from `villain`, and a uniformly random completion of the
    /// remaining board — retrying (up to a bounded number of attempts) whenever a sampled
    /// combination collides on a card, so the retry logic can never silently bias the result
    /// toward whichever range happened to be listed first.
    ///
    /// - Parameters:
    ///   - iterations: target number of valid (non-colliding) trials.
    ///   - seed: `Equity.defaultSeed` unless overridden — same seed always produces the same
    ///     result, so tests built on this are never flaky.
    public static func monteCarlo(
        hero: [HoleCards],
        villain: [HoleCards],
        board: [Card] = [],
        iterations: Int = Equity.defaultMonteCarloIterations,
        seed: UInt64 = Equity.defaultSeed
    ) -> EquityResult {
        precondition(!hero.isEmpty && !villain.isEmpty, "both ranges must be non-empty")
        precondition(board.count <= 5, "board can have at most 5 cards")

        var rng = SplitMix64(seed: seed)
        let needed = 5 - board.count
        let maxAttempts = max(iterations * 50, 10_000)

        var wins = 0, ties = 0, losses = 0, trials = 0, attempts = 0

        while trials < iterations && attempts < maxAttempts {
            attempts += 1
            guard let heroHand = hero.randomElement(using: &rng),
                  let villainHand = villain.randomElement(using: &rng) else { continue }

            let known = [heroHand.first, heroHand.second, villainHand.first, villainHand.second] + board
            let usedSet = Set(known)
            guard usedSet.count == known.count else { continue } // card collision — retry

            var pool = fullDeck.filter { !usedSet.contains($0) }
            guard pool.count >= needed else { continue }

            var drawn: [Card] = []
            drawn.reserveCapacity(needed)
            for _ in 0..<needed {
                let index = Int(rng.next() % UInt64(pool.count))
                drawn.append(pool.remove(at: index))
            }

            let fullBoard = board + drawn
            let heroStrength = HandEvaluator.bestHand(from: [heroHand.first, heroHand.second] + fullBoard)
            let villainStrength = HandEvaluator.bestHand(from: [villainHand.first, villainHand.second] + fullBoard)
            trials += 1
            if heroStrength > villainStrength { wins += 1 }
            else if heroStrength == villainStrength { ties += 1 }
            else { losses += 1 }
        }

        return EquityResult(
            winRate: trials > 0 ? Double(wins) / Double(trials) : 0,
            tieRate: trials > 0 ? Double(ties) / Double(trials) : 0,
            loseRate: trials > 0 ? Double(losses) / Double(trials) : 0,
            trials: trials,
            isExact: false
        )
    }

    /// Every concrete `HoleCards` combo for a canonical hand string ("AA", "AKs", "72o") —
    /// 6 combos for a pair (`C(4,2)`), 4 for suited (one per suit), 12 for offsuit
    /// (`4 × 3`). Returns `[]` for a malformed notation, matching `HoleCards(canonical:)`'s
    /// own failable-init behavior rather than trapping.
    ///
    /// This exists because **published "AA vs KK ≈ 82.4%" style equity figures are a
    /// combo-weighted average**, not the equity of any single specific suit assignment —
    /// see `EQUITY.md`'s "A subtlety: which suits?" section. `canonicalVsCanonical` is what
    /// actually reproduces those numbers; `headsUp`/`monteCarlo` answer a more specific
    /// question (this exact pair of concrete hands) that happens to coincide with the
    /// canonical figure only when the suits are unbiased.
    public static func expandCanonical(_ notation: String) -> [HoleCards] {
        let chars = Array(notation)
        guard chars.count == 2 || chars.count == 3,
              let r1 = Rank.from(symbol: chars[0]),
              let r2 = Rank.from(symbol: chars[1]) else { return [] }

        if chars.count == 2 {
            guard r1 == r2 else { return [] }
            var combos: [HoleCards] = []
            let suits = Suit.allCases
            for i in 0..<suits.count {
                for j in (i + 1)..<suits.count {
                    combos.append(HoleCards(Card(rank: r1, suit: suits[i]), Card(rank: r2, suit: suits[j]))!)
                }
            }
            return combos
        }

        guard r1 != r2, chars[2] == "s" || chars[2] == "o" else { return [] }
        var combos: [HoleCards] = []
        if chars[2] == "s" {
            for suit in Suit.allCases {
                combos.append(HoleCards(Card(rank: r1, suit: suit), Card(rank: r2, suit: suit))!)
            }
        } else {
            for suit1 in Suit.allCases {
                for suit2 in Suit.allCases where suit2 != suit1 {
                    combos.append(HoleCards(Card(rank: r1, suit: suit1), Card(rank: r2, suit: suit2))!)
                }
            }
        }
        return combos
    }

    /// Combo-weighted Monte Carlo equity between two canonical hand notations — expands
    /// each into every concrete combo and runs `rangeVsRange` across them. This is what
    /// published "AA vs KK" style reference numbers actually mean; see `expandCanonical`.
    public static func canonicalVsCanonical(
        _ hero: String,
        _ villain: String,
        board: [Card] = [],
        iterations: Int = Equity.defaultMonteCarloIterations,
        seed: UInt64 = Equity.defaultSeed
    ) -> EquityResult {
        rangeVsRange(
            heroRange: expandCanonical(hero), villainRange: expandCanonical(villain),
            board: board, iterations: iterations, seed: seed
        )
    }

    /// Convenience: one fixed hero hand vs. a villain range.
    public static func handVsRange(
        hero: HoleCards,
        villainRange: [HoleCards],
        board: [Card] = [],
        iterations: Int = Equity.defaultMonteCarloIterations,
        seed: UInt64 = Equity.defaultSeed
    ) -> EquityResult {
        monteCarlo(hero: [hero], villain: villainRange, board: board, iterations: iterations, seed: seed)
    }

    /// Convenience: a hero range vs. a villain range.
    public static func rangeVsRange(
        heroRange: [HoleCards],
        villainRange: [HoleCards],
        board: [Card] = [],
        iterations: Int = Equity.defaultMonteCarloIterations,
        seed: UInt64 = Equity.defaultSeed
    ) -> EquityResult {
        monteCarlo(hero: heroRange, villain: villainRange, board: board, iterations: iterations, seed: seed)
    }

    // MARK: - Combinatorics helper

    /// Calls `action` once per combination of `k` cards chosen from `pool`, backtracking
    /// through a single reused array rather than materializing every combination up front —
    /// `headsUp`'s preflop case walks up to 1,712,304 of these, so avoiding an allocation
    /// per combination (or holding them all in memory at once) matters here.
    private static func forEachCombination(
        of pool: [Card],
        choose k: Int,
        startIndex: Int = 0,
        current: inout [Card],
        action: ([Card]) -> Void
    ) {
        if k == 0 {
            action(current)
            return
        }
        guard pool.count - startIndex >= k else { return }
        for i in startIndex...(pool.count - k) {
            current.append(pool[i])
            forEachCombination(of: pool, choose: k - 1, startIndex: i + 1, current: &current, action: action)
            current.removeLast()
        }
    }
}
