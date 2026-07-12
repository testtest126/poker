import Foundation

/// A card rank, Two through Ace. Raw value is its numeric rank (2...14) so ranks
/// compare and sort naturally.
public enum Rank: Int, CaseIterable, Comparable, Sendable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack = 11, queen = 12, king = 13, ace = 14

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Single-character notation, e.g. "A", "K", "T", "9".
    public var symbol: String {
        switch self {
        case .ace: return "A"
        case .king: return "K"
        case .queen: return "Q"
        case .jack: return "J"
        case .ten: return "T"
        default: return String(rawValue)
        }
    }
}

public enum Suit: String, CaseIterable, Sendable {
    case clubs, diamonds, hearts, spades

    public var symbol: String {
        switch self {
        case .clubs: return "\u{2663}"
        case .diamonds: return "\u{2666}"
        case .hearts: return "\u{2665}"
        case .spades: return "\u{2660}"
        }
    }
}

public struct Card: Hashable, Sendable {
    public let rank: Rank
    public let suit: Suit

    public init(rank: Rank, suit: Suit) {
        self.rank = rank
        self.suit = suit
    }

    public var description: String { "\(rank.symbol)\(suit.symbol)" }
}
