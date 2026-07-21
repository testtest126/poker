import Foundation

/// The nine standard poker hand categories, ordered weakest to lowest `rawValue` so
/// `Comparable` conformance falls straight out of the raw value — no separate ranking
/// table to keep in sync.
public enum HandCategory: Int, Comparable, Sendable, CustomStringConvertible {
    case highCard, pair, twoPair, trips, straight, flush, fullHouse, quads, straightFlush

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public var description: String {
        switch self {
        case .highCard: return "High Card"
        case .pair: return "Pair"
        case .twoPair: return "Two Pair"
        case .trips: return "Three of a Kind"
        case .straight: return "Straight"
        case .flush: return "Flush"
        case .fullHouse: return "Full House"
        case .quads: return "Four of a Kind"
        case .straightFlush: return "Straight Flush"
        }
    }
}

/// A fully comparable strength for one specific best-5-card poker hand: its category, plus
/// enough rank tiebreakers (most significant first) to break every tie the category leaves
/// open — kicker included. Two `HandStrength`s only ever have differently-shaped
/// `tiebreakers` arrays when they're different categories, and `<`/`==` check category
/// first, so a shape mismatch is never actually compared element-by-element.
public struct HandStrength: Comparable, Sendable {
    public let category: HandCategory
    public let tiebreakers: [Int]

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        for (l, r) in zip(lhs.tiebreakers, rhs.tiebreakers) where l != r {
            return l < r
        }
        return false
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.category == rhs.category && lhs.tiebreakers == rhs.tiebreakers
    }
}

/// Evaluates the best possible 5-card poker hand out of 5, 6, or 7 cards — the foundation
/// `Equity` is built on. No shortcuts: every category is derived from actual rank/suit
/// counts, not a lookup table, so it's exercised (and testable) the same way for every hand.
///
/// **Performance note:** `bestHand(from:)` for 6-7 cards evaluates every 5-card sub-hand
/// (`C(6,5) = 6` or `C(7,5) = 21`) and keeps the best by `Comparable` — the textbook
/// correct approach, deliberately not the fastest one (real solvers use precomputed lookup
/// tables). `Equity`'s exact-enumeration mode calls this millions of times per matchup, so
/// the 7-card path avoids array-allocation overhead where cheap to (a static index table
/// instead of a general combinations generator, fixed-size rank counting instead of a
/// dictionary) — see `EQUITY.md`'s performance note for actual measured timing.
public enum HandEvaluator {
    /// The 21 ways to choose 5 indices out of 7, precomputed once — avoids generating this
    /// with a general-purpose combinations function on every `bestHand(from:)` call, since
    /// this is `Equity`'s hottest inner loop.
    private static let sevenChooseFiveIndices: [(Int, Int, Int, Int, Int)] = {
        var result: [(Int, Int, Int, Int, Int)] = []
        for a in 0..<7 {
            for b in (a + 1)..<7 {
                for c in (b + 1)..<7 {
                    for d in (c + 1)..<7 {
                        for e in (d + 1)..<7 {
                            result.append((a, b, c, d, e))
                        }
                    }
                }
            }
        }
        return result
    }()

    /// The best 5-card `HandStrength` achievable from `cards` (5, 6, or 7 of them).
    public static func bestHand(from cards: [Card]) -> HandStrength {
        precondition((5...7).contains(cards.count), "bestHand(from:) needs 5-7 cards, got \(cards.count)")

        switch cards.count {
        case 5:
            return evaluate5(cards[0], cards[1], cards[2], cards[3], cards[4])
        case 7:
            var best: HandStrength?
            for (a, b, c, d, e) in sevenChooseFiveIndices {
                let candidate = evaluate5(cards[a], cards[b], cards[c], cards[d], cards[e])
                if best == nil || candidate > best! { best = candidate }
            }
            return best!
        default: // 6
            var best: HandStrength?
            for skip in 0..<6 {
                var five: [Card] = []
                five.reserveCapacity(5)
                for (i, card) in cards.enumerated() where i != skip { five.append(card) }
                let candidate = evaluate5(five[0], five[1], five[2], five[3], five[4])
                if best == nil || candidate > best! { best = candidate }
            }
            return best!
        }
    }

    /// Evaluates exactly 5 cards. `private` — always reached through `bestHand(from:)`, the
    /// only entry point `Equity` (or a test) should need.
    private static func evaluate5(_ a: Card, _ b: Card, _ c: Card, _ d: Card, _ e: Card) -> HandStrength {
        var ranks = [a.rank.rawValue, b.rank.rawValue, c.rank.rawValue, d.rank.rawValue, e.rank.rawValue]
        ranks.sort(by: >)

        let isFlush = a.suit == b.suit && b.suit == c.suit && c.suit == d.suit && d.suit == e.suit

        var straightHigh: Int?
        if Set(ranks).count == 5 {
            if ranks[0] - ranks[4] == 4 {
                straightHigh = ranks[0]
            } else if ranks == [14, 5, 4, 3, 2] {
                straightHigh = 5 // the wheel: A-2-3-4-5, plays as a 5-high straight
            }
        }

        // Rank counts via a fixed 15-slot array (indices 2...14) rather than a Dictionary —
        // this function runs millions of times inside Equity's exact enumeration.
        var countByRank = [Int](repeating: 0, count: 15)
        for r in ranks { countByRank[r] += 1 }

        var groups: [(rank: Int, count: Int)] = []
        for r in stride(from: 14, through: 2, by: -1) where countByRank[r] > 0 {
            groups.append((r, countByRank[r]))
        }
        groups.sort { $0.count != $1.count ? $0.count > $1.count : $0.rank > $1.rank }

        if let high = straightHigh, isFlush {
            return HandStrength(category: .straightFlush, tiebreakers: [high])
        }
        if groups[0].count == 4 {
            return HandStrength(category: .quads, tiebreakers: [groups[0].rank, groups[1].rank])
        }
        if groups[0].count == 3, groups.count > 1, groups[1].count >= 2 {
            return HandStrength(category: .fullHouse, tiebreakers: [groups[0].rank, groups[1].rank])
        }
        if isFlush {
            return HandStrength(category: .flush, tiebreakers: ranks)
        }
        if let high = straightHigh {
            return HandStrength(category: .straight, tiebreakers: [high])
        }
        if groups[0].count == 3 {
            return HandStrength(category: .trips, tiebreakers: [groups[0].rank] + groups[1...].map(\.rank))
        }
        if groups[0].count == 2, groups.count > 1, groups[1].count == 2 {
            return HandStrength(category: .twoPair, tiebreakers: [groups[0].rank, groups[1].rank, groups[2].rank])
        }
        if groups[0].count == 2 {
            return HandStrength(category: .pair, tiebreakers: [groups[0].rank] + groups[1...].map(\.rank))
        }
        return HandStrength(category: .highCard, tiebreakers: ranks)
    }
}
