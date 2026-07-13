import SwiftUI
import SwiftData
import PokerKit

struct LeakAnalysisView: View {
    @Query private var records: [HandRecord]

    private var parsedHands: [ParsedHand] {
        records.compactMap { HandHistoryParser.parse($0.rawText).hands.first }
    }

    private var report: LeakReport? {
        guard !parsedHands.isEmpty else { return nil }
        return LeakAnalysisEngine.analyze(hands: parsedHands)
    }

    var body: some View {
        List {
            Section {
                privacyNote
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if let report {
                Section("Overview") {
                    overviewGrid(report)
                }

                Section("Top Leaks") {
                    findingsList(report.findings)
                }

                Section("Push/Fold Adherence") {
                    pushFoldSummary(report.pushFoldAdherence, minSpots: report.minPushFoldSpotsForConfidence)
                }

                if !report.positionStats.isEmpty {
                    Section("By Position") {
                        ForEach(report.positionStats) { stats in
                            positionRow(stats, minHands: report.minHandsForConfidence)
                        }
                    }
                }
            } else {
                Section {
                    ContentUnavailableView(
                        "No Hands To Analyze",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text("Import a PokerStars hand-history file first — the leak finder runs on your imported hands.")
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Leak Finder")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var privacyNote: some View {
        Label {
            Text("Analyzed entirely on this device. Nothing is uploaded or leaves your phone.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "lock.shield")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Overview

    private func overviewGrid(_ report: LeakReport) -> some View {
        let tendencies = report.overallTendencies
        let showdown = report.overallShowdown
        return VStack(spacing: 16) {
            HStack {
                statTile(title: "Hands Analyzed", value: "\(tendencies.handsPlayed)", identifier: "handsAnalyzedValue")
                statTile(title: "VPIP", value: percentage(tendencies.vpipRate), identifier: "vpipValue")
            }
            HStack {
                statTile(title: "PFR", value: percentage(tendencies.pfrRate), identifier: "pfrValue")
                statTile(title: "Open-Limp", value: percentage(tendencies.openLimpRate), identifier: "openLimpValue")
            }
            HStack {
                statTile(title: "Went to Showdown", value: percentage(showdown.showdownRate), identifier: "wtsdValue")
                statTile(
                    title: "Net Chips",
                    value: showdown.netChips.formatted(.number.sign(strategy: .always())),
                    tint: showdown.netChips > 0 ? .green : (showdown.netChips < 0 ? .red : .primary),
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

    // MARK: - Findings

    private func findingsList(_ findings: [LeakFinding]) -> some View {
        Group {
            if findings.isEmpty {
                Text("No clear leaks yet — keep importing hands to build a bigger sample.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(findings) { finding in
                    findingRow(finding)
                }
            }
        }
    }

    private func findingRow(_ finding: LeakFinding) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(finding.title)
                    .font(.subheadline.bold())
                if finding.isTentative {
                    Text("Tentative")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.2), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
            Text(finding.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("finding-\(finding.id)")
    }

    // MARK: - Push/fold adherence

    private func pushFoldSummary(_ adherence: PushFoldAdherenceReport, minSpots: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if adherence.applicableSpots == 0 {
                Text("No unopened short-stack spots (\u{2264}20bb) found yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    statTile(
                        title: "Adherence",
                        value: percentage(adherence.adherenceRate),
                        identifier: "pushFoldAdherenceValue"
                    )
                    statTile(title: "Spots", value: "\(adherence.matches)/\(adherence.applicableSpots)", identifier: "pushFoldSpotsValue")
                }
                if adherence.applicableSpots < minSpots {
                    Text("Small sample so far — treat this as a tentative signal, not a verdict.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if !adherence.deviations.isEmpty {
                    Divider()
                    ForEach(Array(adherence.deviations.prefix(5))) { deviation in
                        deviationRow(deviation)
                    }
                    if adherence.deviations.count > 5 {
                        Text("+\(adherence.deviations.count - 5) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func deviationRow(_ deviation: PushFoldDeviation) -> some View {
        HStack {
            Text(deviation.hand.notation)
                .font(.subheadline.bold())
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(deviation.position.rawValue) · \(Int(deviation.effectiveStackBB))bb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(deviation.kind == .missedShove ? "You folded — model shoves" : "You shoved — model folds")
                    .font(.caption)
                    .foregroundStyle(deviation.kind == .missedShove ? .orange : .red)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - By position

    private func positionRow(_ stats: PositionStats, minHands: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(stats.position)
                        .font(.subheadline.bold())
                    if stats.tendencies.handsPlayed < minHands {
                        Text("tentative")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                Text("\(stats.tendencies.handsPlayed) hands · VPIP \(percentage(stats.tendencies.vpipRate)) · PFR \(percentage(stats.tendencies.pfrRate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(stats.showdown.netChips.formatted(.number.sign(strategy: .always())))
                .font(.subheadline.bold())
                .foregroundStyle(stats.showdown.netChips > 0 ? .green : (stats.showdown.netChips < 0 ? .red : .secondary))
        }
        .padding(.vertical, 2)
    }

    // MARK: - Formatting

    private func percentage(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f%%", value * 100)
    }
}

#Preview {
    NavigationStack {
        LeakAnalysisView()
    }
    .modelContainer(for: HandRecord.self, inMemory: true)
}
