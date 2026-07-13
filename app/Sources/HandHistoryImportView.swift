import SwiftUI
import SwiftData
import PokerKit

struct HandHistoryImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HandRecord.date, order: .reverse) private var records: [HandRecord]

    @State private var isPresentingImporter = false
    @State private var lastImportSummary: ImportSummary?
    @State private var importErrorMessage: String?

    var body: some View {
        List {
            Section {
                privacyNote
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                NavigationLink {
                    LeakAnalysisView()
                } label: {
                    Label("View Leak Report", systemImage: "chart.bar.doc.horizontal")
                }
                .accessibilityIdentifier("leakReportLink")
            }

            if let summary = lastImportSummary {
                Section("Last Import") {
                    importSummaryView(summary)
                }
            }

            Section("All Imported Hands") {
                if records.isEmpty {
                    ContentUnavailableView(
                        "No Hands Imported",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Import a PokerStars hand-history .txt file to get started.")
                    )
                } else {
                    overallStatsHeader
                    ForEach(records) { record in
                        HandRow(record: record)
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Hand History Import")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingImporter = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("importButton")
            }
        }
        .fileImporter(
            isPresented: $isPresentingImporter,
            allowedContentTypes: [.plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert(
            "Import Failed",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("OK") { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private var privacyNote: some View {
        Label {
            Text("Parsed entirely on this device. Nothing is uploaded or leaves your phone.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "lock.shield")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Import summary (most recent import)

    private struct ImportSummary {
        let handsImported: Int
        let duplicatesSkipped: Int
        let malformedSkipped: Int
        let tournamentCount: Int
        let handsWithFlopSeen: Int
        let netChips: Decimal
    }

    private func importSummaryView(_ summary: ImportSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(summary.handsImported) hand\(summary.handsImported == 1 ? "" : "s") imported")
                    .font(.headline)
                Spacer()
                Text(summary.netChips.formatted(.number.sign(strategy: .always())))
                    .font(.headline)
                    .foregroundStyle(summary.netChips > 0 ? .green : (summary.netChips < 0 ? .red : .secondary))
                    .accessibilityIdentifier("lastImportNetChips")
            }
            Text("\(summary.tournamentCount) tournament\(summary.tournamentCount == 1 ? "" : "s") · \(summary.handsWithFlopSeen) saw a flop")
                .font(.caption)
                .foregroundStyle(.secondary)
            if summary.duplicatesSkipped > 0 {
                Text("\(summary.duplicatesSkipped) already imported, skipped")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if summary.malformedSkipped > 0 {
                Text("\(summary.malformedSkipped) hand\(summary.malformedSkipped == 1 ? "" : "s") couldn't be parsed and were skipped")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - All-time stats

    private var overallStatsHeader: some View {
        let tournamentCount = Set(records.compactMap(\.tournamentId)).count
        let flopSeenCount = records.filter(\.heroSawFlop).count
        let netChips = records.reduce(Decimal(0)) { $0 + $1.heroNetChips }
        let flopFraction = records.isEmpty ? nil : Decimal(flopSeenCount) / Decimal(records.count)

        return VStack(spacing: 16) {
            HStack {
                statTile(title: "Hands", value: "\(records.count)", identifier: "handsImportedValue")
                statTile(title: "Tournaments", value: "\(tournamentCount)", identifier: "tournamentCountValue")
            }
            HStack {
                statTile(title: "Saw Flop", value: percentage(flopFraction), identifier: "flopSeenValue")
                statTile(
                    title: "Net Chips",
                    value: netChips.formatted(),
                    tint: netChips > 0 ? .green : (netChips < 0 ? .red : .primary),
                    identifier: "netChipsValue"
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func statTile(title: String, value: String, tint: Color = .primary, identifier: String) -> some View {
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

    private func percentage(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return (value * 100).formatted(.number.precision(.fractionLength(0...1))) + "%"
    }

    // MARK: - Import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importErrorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            importFile(at: url)
        }
    }

    private func importFile(at url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            importErrorMessage = "Couldn't read that file. Make sure it's a plain-text PokerStars hand-history export."
            return
        }

        let file = HandHistoryParser.parse(text)
        guard !file.hands.isEmpty else {
            importErrorMessage = "No hands were found in that file. Make sure it's an unedited PokerStars hand-history export."
            return
        }

        let existingIds = Set(records.map(\.handId))
        var inserted = 0
        for hand in file.hands where !existingIds.contains(hand.handId) {
            modelContext.insert(HandRecord(hand: hand))
            inserted += 1
        }

        let tournamentIds = Set(file.hands.compactMap(\.tournamentId))
        lastImportSummary = ImportSummary(
            handsImported: inserted,
            duplicatesSkipped: file.hands.count - inserted,
            malformedSkipped: file.skipped.count,
            tournamentCount: tournamentIds.count,
            handsWithFlopSeen: file.hands.filter(\.heroSawFlop).count,
            netChips: file.hands.reduce(0) { $0 + $1.heroNetChips }
        )
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
    }
}

private struct HandRow: View {
    let record: HandRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.heroHoleCardsDescription ?? "Unknown hand")
                    .font(.headline)
                HStack(spacing: 6) {
                    if let position = record.heroPosition {
                        Text(position)
                    }
                    if let date = record.date {
                        Text("·")
                        Text(date, format: .dateTime.month(.abbreviated).day().year())
                    }
                    if record.heroSawFlop {
                        Text("· saw flop")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(record.heroNetChips.formatted(.number.sign(strategy: .always())))
                    .font(.subheadline.bold())
                    .foregroundStyle(record.heroNetChips > 0 ? .green : (record.heroNetChips < 0 ? .red : .secondary))
                if let bounty = record.heroBountyWon {
                    Text("+\(bounty.formatted(.currency(code: "USD"))) KO")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HandHistoryImportView()
    }
    .modelContainer(for: HandRecord.self, inMemory: true)
}
