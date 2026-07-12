import Foundation

/// Two hole cards. Order doesn't matter for equality or hand strength — what matters
/// is the pair of ranks and whether they share a suit.
public struct HoleCards: Hashable, Sendable {
    public let first: Card
    public let second: Card

    /// Fails if the two cards are identical (same rank and suit).
    public init?(_ first: Card, _ second: Card) {
        guard first != second else { return nil }
        self.first = first
        self.second = second
    }

    public var isPair: Bool { first.rank == second.rank }
    public var isSuited: Bool { first.suit == second.suit }

    public var highRank: Rank { max(first.rank, second.rank) }
    public var lowRank: Rank { min(first.rank, second.rank) }

    /// Canonical starting-hand notation, e.g. "AA", "AKs", "T9o".
    public var notation: String {
        if isPair { return "\(highRank.symbol)\(highRank.symbol)" }
        return "\(highRank.symbol)\(lowRank.symbol)\(isSuited ? "s" : "o")"
    }

    /// One representative `HoleCards` for a canonical hand string like "AKs", "77", "T9o".
    /// Suits are picked arbitrarily (consistent with the requested suited/offsuit flag) —
    /// useful for tests and for range lookups that only care about the canonical hand.
    public init?(canonical: String) {
        let chars = Array(canonical)
        guard chars.count == 2 || chars.count == 3 else { return nil }
        guard let r1 = Rank.from(symbol: chars[0]), let r2 = Rank.from(symbol: chars[1]) else { return nil }

        if chars.count == 2 {
            guard r1 == r2 else { return nil }
            self.init(Card(rank: r1, suit: .clubs), Card(rank: r2, suit: .diamonds))
            return
        }

        let suitedFlag = chars[2]
        guard suitedFlag == "s" || suitedFlag == "o" else { return nil }
        guard r1 != r2 else { return nil }
        let a = Card(rank: r1, suit: .clubs)
        let b = Card(rank: r2, suit: suitedFlag == "s" ? .clubs : .diamonds)
        self.init(a, b)
    }

    public static func random(using generator: inout RandomNumberGenerator) -> HoleCards {
        var deck: [Card] = []
        for rank in Rank.allCases {
            for suit in Suit.allCases {
                deck.append(Card(rank: rank, suit: suit))
            }
        }
        deck.shuffle(using: &generator)
        return HoleCards(deck[0], deck[1])!
    }

    public static func random() -> HoleCards {
        var rng: RandomNumberGenerator = SystemRandomNumberGenerator()
        return random(using: &rng)
    }
}

extension Rank {
    static func from(symbol: Character) -> Rank? {
        switch symbol {
        case "A", "a": return .ace
        case "K", "k": return .king
        case "Q", "q": return .queen
        case "J", "j": return .jack
        case "T", "t": return .ten
        default:
            guard let digit = symbol.wholeNumberValue, (2...9).contains(digit) else { return nil }
            return Rank(rawValue: digit)
        }
    }
}
