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

@Test func defaultsAreTournamentWithEmptyNotes() {
    let entry = BankrollEntry(date: .now, tournamentName: "Daily Bounty", buyIn: 20)
    #expect(entry.sessionType == .tournament)
    #expect(entry.notes == "")
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

@Test func sessionCountMatchesEntryCount() {
    let entries = [
        BankrollEntry(date: .now, tournamentName: "A", buyIn: 10, cash: 0),
        BankrollEntry(date: .now, tournamentName: "B", buyIn: 10, cash: 20),
        BankrollEntry(date: .now, tournamentName: "C", buyIn: 10, cash: 5),
    ]
    #expect(entries.sessionCount == 3)
    #expect([BankrollEntry]().sessionCount == 0)
}

@Test func winRateCountsProfitablePositiveSessions() {
    let entries = [
        BankrollEntry(date: .now, tournamentName: "Win", buyIn: 10, cash: 20),
        BankrollEntry(date: .now, tournamentName: "Lose", buyIn: 10, cash: 0),
        BankrollEntry(date: .now, tournamentName: "Breakeven", buyIn: 10, cash: 10),
    ]
    // Only strictly positive profit counts as a win; breakeven does not.
    #expect(entries.winRate == Decimal(1) / Decimal(3))
}

@Test func winRateIsNilWithNoEntries() {
    let entries: [BankrollEntry] = []
    #expect(entries.winRate == nil)
}

@Test func winRateIsZeroWhenAllSessionsLose() {
    let entries = [
        BankrollEntry(date: .now, tournamentName: "A", buyIn: 10, cash: 0),
        BankrollEntry(date: .now, tournamentName: "B", buyIn: 10, cash: 5),
    ]
    #expect(entries.winRate == 0)
}

@Test func runningBankrollAccumulatesInChronologicalOrder() {
    let day1 = Date(timeIntervalSince1970: 1_000)
    let day2 = Date(timeIntervalSince1970: 2_000)
    let day3 = Date(timeIntervalSince1970: 3_000)

    // Deliberately out of order to verify sorting by date, not insertion order.
    let entries = [
        BankrollEntry(date: day3, tournamentName: "C", buyIn: 10, cash: 40),
        BankrollEntry(date: day1, tournamentName: "A", buyIn: 100, cash: 150),
        BankrollEntry(date: day2, tournamentName: "B", buyIn: 50, cash: 0),
    ]

    let running = entries.runningBankroll()
    #expect(running.map(\.entry.tournamentName) == ["A", "B", "C"])
    #expect(running.map(\.balance) == [50, 0, 30])
}

@Test func runningBankrollHonorsStartingBalance() {
    let entries = [
        BankrollEntry(date: .now, tournamentName: "A", buyIn: 100, cash: 150),
    ]
    #expect(entries.runningBankroll(startingBalance: 200).map(\.balance) == [250])
}

@Test func runningBankrollIsEmptyForNoEntries() {
    let entries: [BankrollEntry] = []
    #expect(entries.runningBankroll().isEmpty)
}
