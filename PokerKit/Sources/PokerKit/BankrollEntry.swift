import Foundation

/// A single tournament result: what was paid in, and what (if anything) came back.
public struct BankrollEntry: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let date: Date
    public let tournamentName: String
    public let buyIn: Decimal
    public let cash: Decimal

    public init(
        id: UUID = UUID(),
        date: Date,
        tournamentName: String,
        buyIn: Decimal,
        cash: Decimal = 0
    ) {
        self.id = id
        self.date = date
        self.tournamentName = tournamentName
        self.buyIn = buyIn
        self.cash = cash
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
}
