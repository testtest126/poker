import Foundation

/// Omaha's defining hand-construction rule, and the *only* thing that makes Omaha hand
/// evaluation different from Hold'em's "best 5 of any 7": the best 5-card hand must use
/// **exactly 2** of hero's 4 hole cards and **exactly 3** of the 5 board cards — never more,
/// never fewer of either. A hole card you don't use is simply dead; you cannot "borrow" a
/// 3rd hole card even if it would make a better hand, and you cannot play the board alone
/// (0 hole cards) or with only 1.
///
/// **This module doesn't re-rank anything** — `HandEvaluator` (unmodified) still does 100% of
/// the actual 5-card ranking. `OmahaHandEvaluator` only enumerates which 5-card
/// *combinations* are legal to hand to it: exactly `C(4,2) × C(5,3) = 6 × 10 = 60` per hole/
/// board pairing, taking the best of all 60. See `ai-docs/OMAHA.md` for the tests that prove
/// this constraint is actually enforced (not just assumed) — the two clearest cases are a
/// hole hand that could look like quads/a flush if the 2-card cap were ignored, but can't
/// legally reach that hand once it's enforced.
public enum OmahaHandEvaluator {
    /// The `C(4,2) = 6` ways to choose 2 of 4 hole-card indices, precomputed once.
    private static let fourChooseTwoIndices: [(Int, Int)] = {
        var result: [(Int, Int)] = []
        for a in 0..<4 {
            for b in (a + 1)..<4 {
                result.append((a, b))
            }
        }
        return result
    }()

    /// The `C(5,3) = 10` ways to choose 3 of 5 board-card indices, precomputed once.
    private static let fiveChooseThreeIndices: [(Int, Int, Int)] = {
        var result: [(Int, Int, Int)] = []
        for a in 0..<5 {
            for b in (a + 1)..<5 {
                for c in (b + 1)..<5 {
                    result.append((a, b, c))
                }
            }
        }
        return result
    }()

    /// The best *legal* 5-card `HandStrength` for `hole` given a **completed** 5-card
    /// `board`. Requires the full river (unlike `HandEvaluator.bestHand`, which accepts 5-7
    /// cards) because Omaha's 2-and-3 split is only well-defined against a specific board
    /// size — evaluating "best legal hand on the turn" is a different, `OmahaEquity`-level
    /// concept (averaging over every possible river), not something this function does
    /// itself.
    public static func bestHand(hole: OmahaHoleCards, board: [Card]) -> HandStrength {
        precondition(board.count == 5, "OmahaHandEvaluator.bestHand needs a completed 5-card board, got \(board.count)")

        var best: HandStrength?
        for (h1, h2) in fourChooseTwoIndices {
            for (b1, b2, b3) in fiveChooseThreeIndices {
                let five = [hole.cards[h1], hole.cards[h2], board[b1], board[b2], board[b3]]
                let candidate = HandEvaluator.bestHand(from: five)
                if best == nil || candidate > best! { best = candidate }
            }
        }
        return best!
    }
}
