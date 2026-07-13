import Foundation

/// A betting round within a hand.
public enum Street: String, CaseIterable, Sendable, Equatable {
    case preflop, flop, turn, river
}

/// The kind of action a player took. Blind/ante posts are modeled as actions so a
/// hero's total investment in a hand is just the sum of their action amounts.
public enum ActionKind: String, Sendable, Equatable {
    case postAnte
    case postSmallBlind
    case postBigBlind
    case fold
    case check
    case call
    case bet
    case raise
}

/// One action taken by one player on one street. `amount` is the number of chips
/// that action put into the pot (0 for folds/checks); for a raise it's the
/// incremental amount added this action, not the new total bet.
public struct HandAction: Sendable, Equatable {
    public let street: Street
    public let player: String
    public let kind: ActionKind
    public let amount: Decimal
    public let isAllIn: Bool

    public init(street: Street, player: String, kind: ActionKind, amount: Decimal, isAllIn: Bool = false) {
        self.street = street
        self.player = player
        self.kind = kind
        self.amount = amount
        self.isAllIn = isAllIn
    }
}

/// A single hand parsed from a PokerStars hand-history file, from the hero's
/// point of view. The hero is identified by whichever player the file deals hole
/// cards to (PokerStars only ever shows hole cards for the account the history
/// was exported for).
public struct ParsedHand: Sendable, Equatable {
    public let handId: String
    public let tournamentId: String?
    public let date: Date?
    public let smallBlind: Decimal
    public let bigBlind: Decimal
    public let ante: Decimal

    public let heroName: String
    public let heroSeat: Int?
    /// Standard position label ("BTN", "SB", "BB", "UTG", "UTG+1", "MP", "HJ", "CO"),
    /// derived from seat count and distance from the button. Nil if it couldn't be
    /// determined (e.g. button seat not found).
    public let heroPosition: String?
    public let heroHoleCards: HoleCards?
    public let heroStartingStack: Decimal?

    public let actions: [HandAction]
    public let board: [Card]

    /// Hero's net chip result for the hand: total collected/returned minus total invested.
    public let heroNetChips: Decimal
    /// The bounty hero collected this hand for eliminating an opponent, if any (PKO tournaments).
    public let heroBountyWon: Decimal?

    public let rawText: String

    public init(
        handId: String,
        tournamentId: String?,
        date: Date?,
        smallBlind: Decimal,
        bigBlind: Decimal,
        ante: Decimal,
        heroName: String,
        heroSeat: Int?,
        heroPosition: String?,
        heroHoleCards: HoleCards?,
        heroStartingStack: Decimal?,
        actions: [HandAction],
        board: [Card],
        heroNetChips: Decimal,
        heroBountyWon: Decimal?,
        rawText: String
    ) {
        self.handId = handId
        self.tournamentId = tournamentId
        self.date = date
        self.smallBlind = smallBlind
        self.bigBlind = bigBlind
        self.ante = ante
        self.heroName = heroName
        self.heroSeat = heroSeat
        self.heroPosition = heroPosition
        self.heroHoleCards = heroHoleCards
        self.heroStartingStack = heroStartingStack
        self.actions = actions
        self.board = board
        self.heroNetChips = heroNetChips
        self.heroBountyWon = heroBountyWon
        self.rawText = rawText
    }

    /// True if the hero was still in the hand when the flop was dealt. Checked via
    /// "did the hero fold preflop", not "did the hero act on the flop" — when
    /// remaining players are all-in preflop, PokerStars deals the rest of the board
    /// straight through with no further action lines at all.
    public var heroSawFlop: Bool {
        guard board.count >= 3 else { return false }
        let foldedPreflop = actions.contains { $0.street == .preflop && $0.player == heroName && $0.kind == .fold }
        return !foldedPreflop
    }

    public var heroWonHand: Bool {
        heroNetChips > 0
    }
}

extension ParsedHand: Identifiable {
    public var id: String { handId }
}

/// All hands parsed from one hand-history file, plus anything that couldn't be
/// parsed. Malformed hands are skipped rather than failing the whole import.
public struct HandHistoryFile: Sendable {
    public struct SkippedHand: Sendable, Equatable {
        public let rawText: String
        public let reason: String

        public init(rawText: String, reason: String) {
            self.rawText = rawText
            self.reason = reason
        }
    }

    public let hands: [ParsedHand]
    public let skipped: [SkippedHand]

    public init(hands: [ParsedHand], skipped: [SkippedHand]) {
        self.hands = hands
        self.skipped = skipped
    }

    /// Hands grouped into sessions by tournament id, ordered by each session's
    /// earliest hand. Hands with no tournament id are grouped under `nil`, sorted last.
    public var sessions: [TournamentSession] {
        var order: [String?] = []
        var buckets: [String?: [ParsedHand]] = [:]
        for hand in hands {
            if buckets[hand.tournamentId] == nil {
                buckets[hand.tournamentId] = []
                order.append(hand.tournamentId)
            }
            buckets[hand.tournamentId]!.append(hand)
        }
        let withTournament = order.filter { $0 != nil }
        let withoutTournament = order.filter { $0 == nil }
        return (withTournament + withoutTournament).map { TournamentSession(tournamentId: $0, hands: buckets[$0]!) }
    }
}

/// All hands from a single tournament, grouped together for a per-session summary.
public struct TournamentSession: Sendable, Identifiable {
    public let tournamentId: String?
    public let hands: [ParsedHand]

    public init(tournamentId: String?, hands: [ParsedHand]) {
        self.tournamentId = tournamentId
        self.hands = hands
    }

    public var id: String { tournamentId ?? "unknown-\(hands.first?.handId ?? UUID().uuidString)" }

    public var netChips: Decimal {
        hands.reduce(0) { $0 + $1.heroNetChips }
    }

    public var bountiesWon: Decimal {
        hands.reduce(0) { $0 + ($1.heroBountyWon ?? 0) }
    }

    public var handsWithFlopSeen: Int {
        hands.filter(\.heroSawFlop).count
    }
}
