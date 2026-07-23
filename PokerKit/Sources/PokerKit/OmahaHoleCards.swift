import Foundation

/// Four hole cards — Omaha/PLO's hand size, **added alongside** Hold'em's `HoleCards`, never
/// replacing or modifying it. Every existing NLHE model (`ChenScore`, `PushFoldRange`,
/// `OpeningRange`, `CallingRange`, `ThreeBetRange`, `FourBetRange`, `Equity`) is untouched by
/// this type's existence — see `ai-docs/OMAHA.md` for why Omaha needs its own foundation
/// rather than reusing those (Chen's heuristic and every range model built on it is
/// specifically a 2-card scoring system; it has no defined meaning for 4 cards).
///
/// Stored in a canonical (rank-descending, then suit) order, unlike `HoleCards` (which keeps
/// `first`/`second` in whatever order they were constructed and doesn't normalize) — a
/// 4-card hand has no natural "first/second" the way two hole cards do, so there's no
/// meaningful order to preserve, and canonicalizing means two `OmahaHoleCards` built from the
/// same 4 cards in different input orders compare equal and hash identically.
public struct OmahaHoleCards: Hashable, Sendable {
    public let cards: [Card]

    /// Fails unless `cards` is exactly 4 distinct cards.
    public init?(_ cards: [Card]) {
        guard cards.count == 4, Set(cards).count == 4 else { return nil }
        self.cards = cards.sorted { $0.rank != $1.rank ? $0.rank > $1.rank : $0.suit.rawValue < $1.suit.rawValue }
    }

    public init?(_ a: Card, _ b: Card, _ c: Card, _ d: Card) {
        self.init([a, b, c, d])
    }

    /// Explicit per-card notation, e.g. `"AsAhKdQc"` — four 2-character rank+suit tokens,
    /// unambiguous and exactly round-trips through `init(canonical:)`. Deliberately *not* a
    /// Hold'em-style shorthand ("AAKQs" or similar) — see the type's doc comment and
    /// `suitPattern` below for why this project didn't invent one for Phase 1.
    public var notation: String { cards.map(\.notation).joined() }

    /// Parses `notation`'s own output, or `nil` for anything else (wrong length, an invalid
    /// rank/suit token, or a repeated card).
    public init?(canonical: String) {
        let chars = Array(canonical)
        guard chars.count == 8 else { return nil }
        var parsed: [Card] = []
        parsed.reserveCapacity(4)
        for i in stride(from: 0, to: 8, by: 2) {
            guard let card = Card(notation: String(chars[i...(i + 1)])) else { return nil }
            parsed.append(card)
        }
        self.init(parsed)
    }

    // MARK: - Suit pattern (descriptive, not part of the parseable notation)

    /// How PLO players actually describe a starting hand's suit shape — how many *disjoint
    /// pairs* of the 4 cards could each independently complete a flush. This is **purely
    /// descriptive, computed from the cards**, not part of `notation`/`init(canonical:)` — as
    /// far as this project found, there's no single standardized shorthand for it the way
    /// Hold'em's "s"/"o" suffix is standardized (see `ai-docs/OMAHA.md`), so Phase 1 doesn't
    /// invent one to parse.
    ///
    /// **`.singleSuited` also covers 3-flush and 4-flush hands** (3 or all 4 cards sharing
    /// one suit) — structurally still "exactly one suit has 2+ cards," even though a 3- or
    /// 4-flush is a well-known *weaker* structure than a clean 2+2 single-suited hand (only
    /// 2 of the same-suited cards can ever be used together, per the 2-hole-card rule — see
    /// `OmahaHandEvaluator`). This label is a structural fact, not a strength judgment;
    /// distinguishing "how good" a suit pattern is belongs with the hand-strength work this
    /// project deliberately deferred to Phase 2.
    public enum SuitPattern: String, Sendable {
        case doubleSuited = "Double Suited"
        case singleSuited = "Single Suited"
        case rainbow = "Rainbow"
    }

    public var suitPattern: SuitPattern {
        var counts: [Suit: Int] = [:]
        for card in cards { counts[card.suit, default: 0] += 1 }
        let suitsWithTwoOrMore = counts.values.filter { $0 >= 2 }.count
        if suitsWithTwoOrMore >= 2 { return .doubleSuited }
        if suitsWithTwoOrMore == 1 { return .singleSuited }
        return .rainbow
    }

    public static func random(using generator: inout RandomNumberGenerator) -> OmahaHoleCards {
        var deck: [Card] = []
        for rank in Rank.allCases {
            for suit in Suit.allCases {
                deck.append(Card(rank: rank, suit: suit))
            }
        }
        deck.shuffle(using: &generator)
        return OmahaHoleCards([deck[0], deck[1], deck[2], deck[3]])!
    }

    public static func random() -> OmahaHoleCards {
        var rng: RandomNumberGenerator = SystemRandomNumberGenerator()
        return random(using: &rng)
    }
}

extension Card {
    /// Parses a 2-character rank+suit token like `"As"`, `"Th"`, `"2c"` (suit letter
    /// case-insensitive) — the standard shorthand for writing out one concrete card as text.
    /// Lives here (alongside the first type that needs it) rather than in `Card.swift`
    /// itself, matching `HoleCards.swift`'s own precedent of hosting `Rank.from(symbol:)`
    /// even though `Rank` is declared elsewhere.
    public init?(notation: String) {
        let chars = Array(notation)
        guard chars.count == 2, let rank = Rank.from(symbol: chars[0]) else { return nil }
        switch chars[1] {
        case "s", "S": self.init(rank: rank, suit: .spades)
        case "h", "H": self.init(rank: rank, suit: .hearts)
        case "d", "D": self.init(rank: rank, suit: .diamonds)
        case "c", "C": self.init(rank: rank, suit: .clubs)
        default: return nil
        }
    }

    /// The inverse of `init(notation:)` — e.g. `"As"`, `"Th"`, `"2c"`.
    public var notation: String { "\(rank.symbol)\(Self.suitLetter(suit))" }

    private static func suitLetter(_ suit: Suit) -> String {
        switch suit {
        case .spades: return "s"
        case .hearts: return "h"
        case .diamonds: return "d"
        case .clubs: return "c"
        }
    }
}
