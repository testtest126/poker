import Foundation

/// Win/tie/lose equity for Omaha/PLO hands — the `Equity` counterpart for 4-card hands,
/// built on `OmahaHandEvaluator` (which enforces the 2-hole/3-board rule) instead of
/// `HandEvaluator.bestHand`'s unrestricted "best 5 of 7." See `ai-docs/OMAHA.md` for the
/// validation against published PLO equity figures and this module's performance notes.
///
/// **Scope note**: unlike `Equity`, there's no `expandCanonical`/`canonicalVsCanonical`
/// equivalent here. Omaha has no standardized "canonical starting hand class" shorthand the
/// way Hold'em's "AKs"/"AKo" is standardized (see `OmahaHoleCards.notation`'s doc comment) —
/// building one is exactly the kind of preflop hand-strength judgment call this project
/// deliberately deferred to a later phase (see `ai-docs/OMAHA.md`). This module only ever
/// operates on concrete `OmahaHoleCards` or lists of them, never a hand-class string.
public enum OmahaEquity {
    // MARK: - Exact: hand vs. hand

    /// Exact win/tie/lose equity for `hero` vs. `villain`, given zero or more known board
    /// cards — no sampling error, via `OmahaHandEvaluator.bestHand` at every possible
    /// completion of the remaining board.
    ///
    /// **Tractability is tighter than `Equity.headsUp`'s.** Each board completion costs `120`
    /// 5-card evaluations here (`60` per side, the legal 2+3 enumeration) vs. `42` for
    /// Hold'em's unrestricted 7-card `bestHand` — and Omaha's 8 known hole cards leave fewer
    /// cards to draw the board from, so preflop there are *more* boards to enumerate too
    /// (`C(44,5) = 1,086,008` vs. Hold'em's `C(48,5) = 1,712,304`). Net effect: an exact
    /// preflop `headsUp` call here does roughly **2x** the work of the already slow (several
    /// minutes) Hold'em equivalent — see `OMAHA.md`'s performance note. **This project
    /// deliberately never calls this preflop** (not in a test, not from the app); use
    /// `monteCarlo` there instead. Postflop (a flop or later already known), this is fast —
    /// same shape as `Equity.headsUp`'s own tractability story.
    ///
    /// - Precondition: `hero`, `villain`, and `board` share no cards.
    public static func headsUp(hero: OmahaHoleCards, villain: OmahaHoleCards, board: [Card] = []) -> EquityResult {
        let known = hero.cards + villain.cards + board
        precondition(Set(known).count == known.count, "hero/villain/board share a card")
        precondition(board.count <= 5, "board can have at most 5 cards")

        let usedSet = Set(known)
        let remaining = Equity.fullDeck.filter { !usedSet.contains($0) }
        let needed = 5 - board.count

        var wins = 0, ties = 0, losses = 0, total = 0
        var current: [Card] = []
        current.reserveCapacity(needed)

        forEachCombination(of: remaining, choose: needed, current: &current) { drawn in
            let fullBoard = board + drawn
            let heroHand = OmahaHandEvaluator.bestHand(hole: hero, board: fullBoard)
            let villainHand = OmahaHandEvaluator.bestHand(hole: villain, board: fullBoard)
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
    /// side — identical shape and reproducibility guarantee to `Equity.monteCarlo`, built on
    /// `OmahaHoleCards`/`OmahaHandEvaluator` instead.
    public static func monteCarlo(
        hero: [OmahaHoleCards],
        villain: [OmahaHoleCards],
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

            let known = heroHand.cards + villainHand.cards + board
            let usedSet = Set(known)
            guard usedSet.count == known.count else { continue } // card collision — retry

            var pool = Equity.fullDeck.filter { !usedSet.contains($0) }
            guard pool.count >= needed else { continue }

            var drawn: [Card] = []
            drawn.reserveCapacity(needed)
            for _ in 0..<needed {
                let index = Int(rng.next() % UInt64(pool.count))
                drawn.append(pool.remove(at: index))
            }

            let fullBoard = board + drawn
            let heroStrength = OmahaHandEvaluator.bestHand(hole: heroHand, board: fullBoard)
            let villainStrength = OmahaHandEvaluator.bestHand(hole: villainHand, board: fullBoard)
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

    /// Convenience: one fixed hero hand vs. a villain range.
    public static func handVsRange(
        hero: OmahaHoleCards,
        villainRange: [OmahaHoleCards],
        board: [Card] = [],
        iterations: Int = Equity.defaultMonteCarloIterations,
        seed: UInt64 = Equity.defaultSeed
    ) -> EquityResult {
        monteCarlo(hero: [hero], villain: villainRange, board: board, iterations: iterations, seed: seed)
    }

    /// Convenience: a hero range vs. a villain range.
    public static func rangeVsRange(
        heroRange: [OmahaHoleCards],
        villainRange: [OmahaHoleCards],
        board: [Card] = [],
        iterations: Int = Equity.defaultMonteCarloIterations,
        seed: UInt64 = Equity.defaultSeed
    ) -> EquityResult {
        monteCarlo(hero: heroRange, villain: villainRange, board: board, iterations: iterations, seed: seed)
    }

    // MARK: - Combinatorics helper

    /// Identical in shape to `Equity`'s own combination-walker — duplicated (not shared)
    /// because that one is `private` to `Equity`, both are ~15 lines, and this module
    /// deliberately keeps a zero-diff footprint on `Equity.swift` (see this file's doc
    /// comment) rather than widening an existing type's access control just to share it.
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
