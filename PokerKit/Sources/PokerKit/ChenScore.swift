import Foundation

/// Bill Chen's published starting-hand strength heuristic. It's a well-known, easily
/// verified formula (not a memorized table of equities), which is why `PushFoldRange`
/// uses it to *rank* the 169 starting hands rather than hand-typing 169 equity numbers.
///
/// Steps (per the standard published formula):
/// 1. Score the highest card: A=10, K=8, Q=7, J=6, T=5, else rank/2 (9=4.5 ... 2=1).
/// 2. If it's a pair, double the high-card score (minimum 5).
/// 3. Add 2 if suited.
/// 4. Subtract for the gap between the two ranks: 0=-0, 1=-1, 2=-2, 3=-4, 4+=-5.
/// 5. Add 1 if the gap is 0 or 1 and the higher card is below a Queen (straight potential).
/// 6. Round a half-point score up to the next whole number.
public enum ChenScore {
    public static func score(for hand: HoleCards) -> Double {
        if hand.isPair {
            return max(highCardScore(hand.highRank) * 2, 5)
        }

        var score = highCardScore(hand.highRank)
        if hand.isSuited { score += 2 }

        let gap = gapBetween(hand.highRank, hand.lowRank)
        score -= gapPenalty(gap)

        if gap <= 1 && hand.highRank < .queen {
            score += 1
        }

        return roundHalfUp(score)
    }

    private static func highCardScore(_ rank: Rank) -> Double {
        switch rank {
        case .ace: return 10
        case .king: return 8
        case .queen: return 7
        case .jack: return 6
        case .ten: return 5
        default: return Double(rank.rawValue) / 2
        }
    }

    /// Number of ranks strictly between the two cards, e.g. AK -> 0, AQ -> 1, A2 -> 11.
    private static func gapBetween(_ high: Rank, _ low: Rank) -> Int {
        high.rawValue - low.rawValue - 1
    }

    private static func gapPenalty(_ gap: Int) -> Double {
        switch gap {
        case 0: return 0
        case 1: return 1
        case 2: return 2
        case 3: return 4
        default: return 5
        }
    }

    /// The formula's components only ever produce a whole number or a half (e.g. 9-high
    /// contributes 4.5). Per Chen's rule, a half-point score rounds *up* — toward positive
    /// infinity, so -1.5 becomes -1, not -2 — everything else is already a whole number.
    private static func roundHalfUp(_ score: Double) -> Double {
        abs(score.truncatingRemainder(dividingBy: 1)) == 0.5 ? score.rounded(.up) : score
    }
}
