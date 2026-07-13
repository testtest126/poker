import Foundation

/// The kind of session a bankroll entry records.
public enum SessionType: String, CaseIterable, Identifiable, Sendable, Codable {
    case tournament
    case sitAndGo
    case cashGame

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tournament: return "Tournament"
        case .sitAndGo: return "Sit & Go"
        case .cashGame: return "Cash Game"
        }
    }
}

/// A single logged session: what was paid in, and what (if anything) came back.
public struct BankrollEntry: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let date: Date
    public let tournamentName: String
    public let sessionType: SessionType
    public let buyIn: Decimal
    public let cash: Decimal
    public let notes: String

    public init(
        id: UUID = UUID(),
        date: Date,
        tournamentName: String,
        sessionType: SessionType = .tournament,
        buyIn: Decimal,
        cash: Decimal = 0,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.tournamentName = tournamentName
        self.sessionType = sessionType
        self.buyIn = buyIn
        self.cash = cash
        self.notes = notes
    }

    public var profit: Decimal { cash - buyIn }
}

public extension Sequence where Element == BankrollEntry {
    /// Net profit across all entries.
    var totalProfit: Decimal {
        reduce(0) { $0 + $1.profit }
    }

    /// ROI as a fraction (0.5 == 50%), or nil if no buy-ins were staked.
    var roi: Decimal? {
        let staked = reduce(Decimal(0)) { $0 + $1.buyIn }
        guard staked != 0 else { return nil }
        return totalProfit / staked
    }

    /// Number of logged sessions.
    var sessionCount: Int {
        reduce(0) { count, _ in count + 1 }
    }

    /// Fraction of sessions with positive profit, or nil if there are no entries.
    var winRate: Decimal? {
        var wins = 0
        var total = 0
        for entry in self {
            total += 1
            if entry.profit > 0 { wins += 1 }
        }
        guard total > 0 else { return nil }
        return Decimal(wins) / Decimal(total)
    }
}

public extension Array where Element == BankrollEntry {
    /// Cumulative bankroll after each entry, in chronological order (earliest date first).
    /// Entries with equal dates keep their relative order from the original array.
    func runningBankroll(startingBalance: Decimal = 0) -> [(entry: BankrollEntry, balance: Decimal)] {
        var total = startingBalance
        return sorted { $0.date < $1.date }.map { entry in
            total += entry.profit
            return (entry, total)
        }
    }
}
