import SwiftUI
import SwiftData
import Charts
import PokerKit

struct BankrollTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BankrollEntryRecord.date, order: .reverse) private var records: [BankrollEntryRecord]

    @State private var isPresentingAddForm = false
    @State private var editingRecord: BankrollEntryRecord?

    private var entries: [BankrollEntry] { records.map(\.asEntry) }

    var body: some View {
        List {
            Section {
                summaryHeader
                if entries.count >= 2 {
                    sparkline
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section("Sessions") {
                if records.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Log a tournament or session to start tracking your bankroll.")
                    )
                } else {
                    ForEach(records) { record in
                        BankrollRow(entry: record.asEntry)
                            .contentShape(Rectangle())
                            .onTapGesture { editingRecord = record }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Bankroll Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingAddForm = true
                } label: {
                    Label("Add Session", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddForm) {
            BankrollEntryFormView { newEntry in
                modelContext.insert(BankrollEntryRecord(entry: newEntry))
            }
        }
        .sheet(item: $editingRecord) { record in
            BankrollEntryFormView(existingEntry: record.asEntry) { updated in
                record.apply(updated)
            }
        }
    }

    private var summaryHeader: some View {
        VStack(spacing: 16) {
            HStack {
                statTile(title: "Current Bankroll", value: currency(entries.totalProfit), tint: bankrollTint, identifier: "currentBankrollValue")
                statTile(title: "Total Profit", value: currency(entries.totalProfit, signed: true), tint: bankrollTint, identifier: "totalProfitValue")
            }
            HStack {
                statTile(title: "ROI", value: percentage(entries.roi), tint: .primary, identifier: "roiValue")
                statTile(title: "Sessions", value: "\(entries.sessionCount)", tint: .primary, identifier: "sessionCountValue")
                statTile(title: "Win Rate", value: percentage(entries.winRate), tint: .primary, identifier: "winRateValue")
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var bankrollTint: Color {
        entries.totalProfit > 0 ? .green : (entries.totalProfit < 0 ? .red : .primary)
    }

    private func statTile(title: String, value: String, tint: Color, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sparkline: some View {
        let points = entries.runningBankroll()
        return Chart(Array(points.enumerated()), id: \.offset) { _, point in
            LineMark(
                x: .value("Date", point.entry.date),
                y: .value("Balance", point.balance)
            )
            .interpolationMethod(.monotone)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 60)
        .padding(.horizontal)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
    }

    private func currency(_ value: Decimal, signed: Bool = false) -> String {
        let formatted = value.formatted(.currency(code: "USD"))
        guard signed, value > 0 else { return formatted }
        return "+\(formatted)"
    }

    private func percentage(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return (value * 100).formatted(.number.precision(.fractionLength(0...1))) + "%"
    }
}

private struct BankrollRow: View {
    let entry: BankrollEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.tournamentName)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(entry.sessionType.title)
                    Text("·")
                    Text(entry.date, format: .dateTime.month(.abbreviated).day().year())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(entry.profit.formatted(.currency(code: "USD")))
                .font(.subheadline.bold())
                .foregroundStyle(entry.profit > 0 ? .green : (entry.profit < 0 ? .red : .secondary))
                .accessibilityIdentifier("rowProfit")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        BankrollTrackerView()
    }
    .modelContainer(for: BankrollEntryRecord.self, inMemory: true)
}
