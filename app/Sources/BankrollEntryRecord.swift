import Foundation
import SwiftData
import PokerKit

/// SwiftData-backed persistence for `BankrollEntry`. Kept out of PokerKit so the
/// package's domain logic stays a plain, framework-free model.
@Model
final class BankrollEntryRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var tournamentName: String
    var sessionTypeRawValue: String
    var buyIn: Decimal
    var cash: Decimal
    var notes: String

    init(entry: BankrollEntry) {
        id = entry.id
        date = entry.date
        tournamentName = entry.tournamentName
        sessionTypeRawValue = entry.sessionType.rawValue
        buyIn = entry.buyIn
        cash = entry.cash
        notes = entry.notes
    }

    func apply(_ entry: BankrollEntry) {
        date = entry.date
        tournamentName = entry.tournamentName
        sessionTypeRawValue = entry.sessionType.rawValue
        buyIn = entry.buyIn
        cash = entry.cash
        notes = entry.notes
    }

    var asEntry: BankrollEntry {
        BankrollEntry(
            id: id,
            date: date,
            tournamentName: tournamentName,
            sessionType: SessionType(rawValue: sessionTypeRawValue) ?? .tournament,
            buyIn: buyIn,
            cash: cash,
            notes: notes
        )
    }
}
