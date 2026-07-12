import Foundation
import Testing
@testable import PokerKit

@Test func profitIsCashMinusBuyIn() {
    let entry = BankrollEntry(date: .now, tournamentName: "Sunday Million", buyIn: 100, cash: 350)
    #expect(entry.profit == 250)
}

@Test func bustedEntryHasNegativeProfit() {
    let entry = BankrollEntry(date: .now, tournamentName: "Daily Bounty", buyIn: 20)
    #expect(entry.profit == -20)
}

@Test func totalProfitAndRoiAcrossEntries() {
    let entries = [
        BankrollEntry(date: .now, tournamentName: "A", buyIn: 100, cash: 200),
        BankrollEntry(date: .now, tournamentName: "B", buyIn: 50, cash: 0),
    ]
    #expect(entries.totalProfit == 50)
    #expect(entries.roi == Decimal(50) / Decimal(150))
}

@Test func roiIsNilWithNoBuyIns() {
    let entries: [BankrollEntry] = []
    #expect(entries.roi == nil)
}
