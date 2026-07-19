import SwiftUI
import PokerKit

/// Which range model the grid is currently rendering: short-stack push/fold
/// (`PushFoldRange`) or standard-stack opening/raise-first-in (`OpeningRange`). Purely a
/// view-layer switch — both branches call straight through to `PreflopGrid`, so there's
/// still exactly one decision per model, never a third opinion invented here.
private enum RangeMode: String, CaseIterable, Identifiable {
    case pushFold = "Push/Fold"
    case opening = "Opening"

    var id: String { rawValue }

    var stackRange: ClosedRange<Double> {
        switch self {
        case .pushFold: return 1...20
        case .opening: return 20...100
        }
    }

    var defaultStack: Double {
        switch self {
        case .pushFold: return 10
        case .opening: return 50
        }
    }

    var actionLabel: String {
        switch self {
        case .pushFold: return "Shove"
        case .opening: return "Raise"
        }
    }

    var summarySuffix: String {
        switch self {
        case .pushFold: return "% of hands to shove"
        case .opening: return "% of hands to open"
        }
    }
}

struct PreflopRangeView: View {
    @State private var mode: RangeMode = .pushFold
    @State private var position: Position = .utg
    @State private var effectiveStackBB: Double = RangeMode.pushFold.defaultStack

    /// Whether each of the 169 grid cells is the "aggressive" action (shove, or open) for
    /// the current mode/position/stack — the grid only needs this boolean to render, so
    /// the two decision types (`PushFoldDecision`/`OpeningDecision`) never have to meet.
    private var isAggressiveGrid: [[Bool]] {
        switch mode {
        case .pushFold:
            return PreflopGrid.decisions(position: position, effectiveStackBB: effectiveStackBB)
                .map { row in row.map { $0.action == .push } }
        case .opening:
            return PreflopGrid.openingDecisions(position: position, effectiveStackBB: effectiveStackBB)
                .map { row in row.map { $0.action == .raise } }
        }
    }

    private var actionPercentage: Double {
        let flat = isAggressiveGrid.flatMap { $0 }
        guard !flat.isEmpty else { return 0 }
        return Double(flat.filter { $0 }.count) / Double(flat.count) * 100
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                controls
                summary
                grid
                legend
            }
            .padding()
        }
        .navigationTitle("Preflop Ranges")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Range", selection: $mode) {
                ForEach(RangeMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("rangeModePicker")
            .onChange(of: mode) { _, newMode in
                effectiveStackBB = newMode.defaultStack
            }

            Picker("Position", selection: $position) {
                ForEach(Position.allCases) { position in
                    Text(position.rawValue).tag(position)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("positionPicker")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Effective Stack")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(effectiveStackBB)) bb")
                        .font(.headline)
                        .monospacedDigit()
                        .accessibilityIdentifier("stackValue")
                }
                Slider(value: $effectiveStackBB, in: mode.stackRange, step: 1)
                    .accessibilityIdentifier("stackSlider")
            }
        }
    }

    private var summary: some View {
        Text("\(String(format: "%.0f", actionPercentage))\(mode.summarySuffix)")
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("shovePercentageText")
    }

    private var grid: some View {
        VStack(spacing: 2) {
            ForEach(0..<PreflopGrid.ranks.count, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<PreflopGrid.ranks.count, id: \.self) { col in
                        cell(row: row, col: col)
                    }
                }
            }
        }
    }

    private func cell(row: Int, col: Int) -> some View {
        let notation = PreflopGrid.notation(row: row, col: col)
        let isAggressive = isAggressiveGrid[row][col]

        return Text(notation)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(isAggressive ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundStyle(isAggressive ? Color.white : Color.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .accessibilityIdentifier("cell-\(notation)")
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendSwatch(color: .accentColor, label: mode.actionLabel)
            legendSwatch(color: Color(.secondarySystemBackground), label: "Fold")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.separator))
            Text(label)
        }
    }
}

#Preview {
    NavigationStack {
        PreflopRangeView()
    }
}
