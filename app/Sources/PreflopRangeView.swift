import SwiftUI
import PokerKit

/// Which range model the grid is currently rendering. Purely a view-layer switch — every
/// case calls straight through to `PreflopGrid`, so there's still exactly one decision per
/// model, never a third opinion invented here.
private enum RangeMode: String, CaseIterable, Identifiable {
    case pushFold = "Push/Fold"
    case opening = "Opening"
    case vsShove = "Facing Shove"
    case vsOpen = "Facing Open"

    var id: String { rawValue }

    /// Whether this mode is hero-as-aggressor (one position picker) or hero-as-defender
    /// (an opponent-position picker plus a hero-position picker).
    var isDefending: Bool {
        switch self {
        case .pushFold, .opening: return false
        case .vsShove, .vsOpen: return true
        }
    }

    var stackRange: ClosedRange<Double> {
        switch self {
        case .pushFold, .vsShove: return 1...20
        case .opening, .vsOpen: return 20...100
        }
    }

    var defaultStack: Double {
        switch self {
        case .pushFold, .vsShove: return 10
        case .opening, .vsOpen: return 50
        }
    }

    var legendEntries: [(color: Color, label: String)] {
        switch self {
        case .pushFold: return [(.accentColor, "Shove")]
        case .opening: return [(.accentColor, "Raise")]
        case .vsShove: return [(.accentColor, "Call")]
        case .vsOpen: return [(.accentColor, "3-Bet"), (.teal, "Call")]
        }
    }
}

/// A cell's visual role — collapses all four models' distinct action types (push/raise/
/// call/3-bet/fold) down to what the grid actually needs to render. `.secondary` is only
/// ever produced by `.vsOpen` ("call" as distinct from "3-bet"); every other mode only
/// produces `.primary`/`.fold`.
private enum CellStyle {
    case primary
    case secondary
    case fold

    var color: Color {
        switch self {
        case .primary: return .accentColor
        case .secondary: return .teal
        case .fold: return Color(.secondarySystemBackground)
        }
    }

    var textColor: Color {
        switch self {
        case .primary, .secondary: return .white
        case .fold: return .secondary
        }
    }
}

struct PreflopRangeView: View {
    @State private var mode: RangeMode = .pushFold
    @State private var position: Position = .utg
    @State private var opponentPosition: Position = .utg
    @State private var heroPosition: DefendingPosition = .bigBlind
    @State private var effectiveStackBB: Double = RangeMode.pushFold.defaultStack

    /// `DefendingPosition`s that could plausibly be facing `opponentPosition` — anyone who
    /// acts after them at an unopened table. The big blind is always valid, so it's a safe
    /// fallback default no matter what `opponentPosition` is.
    private var validHeroPositions: [DefendingPosition] {
        DefendingPosition.allCases.filter { $0.actionOrderIndex > opponentPosition.actionOrderIndex }
    }

    private var cellStyles: [[CellStyle]] {
        switch mode {
        case .pushFold:
            return PreflopGrid.decisions(position: position, effectiveStackBB: effectiveStackBB)
                .map { row in row.map { $0.action == .push ? .primary : .fold } }
        case .opening:
            return PreflopGrid.openingDecisions(position: position, effectiveStackBB: effectiveStackBB)
                .map { row in row.map { $0.action == .raise ? .primary : .fold } }
        case .vsShove:
            guard let decisions = PreflopGrid.callingDecisions(
                caller: heroPosition, shover: opponentPosition, effectiveStackBB: effectiveStackBB
            ) else {
                return emptyGrid
            }
            return decisions.map { row in row.map { $0.action == .call ? .primary : .fold } }
        case .vsOpen:
            guard let decisions = PreflopGrid.openDefenseDecisions(
                defender: heroPosition, opener: opponentPosition, effectiveStackBB: effectiveStackBB
            ) else {
                return emptyGrid
            }
            return decisions.map { row in
                row.map { decision in
                    switch decision.action {
                    case .threeBet: return .primary
                    case .call: return .secondary
                    case .fold: return .fold
                    }
                }
            }
        }
    }

    private var emptyGrid: [[CellStyle]] {
        Array(repeating: Array(repeating: .fold, count: PreflopGrid.ranks.count), count: PreflopGrid.ranks.count)
    }

    private var summaryText: String {
        let flat = cellStyles.flatMap { $0 }
        guard !flat.isEmpty else { return "" }
        let total = Double(flat.count)
        let defendCount = flat.filter { $0 != .fold }.count
        let defendPct = Double(defendCount) / total * 100

        switch mode {
        case .pushFold: return "\(String(format: "%.0f", defendPct))% of hands to shove"
        case .opening: return "\(String(format: "%.0f", defendPct))% of hands to open"
        case .vsShove: return "\(String(format: "%.0f", defendPct))% of hands to call"
        case .vsOpen:
            let threeBetCount = flat.filter { $0 == .primary }.count
            let threeBetPct = Double(threeBetCount) / total * 100
            return "\(String(format: "%.0f", defendPct))% of hands to defend "
                + "(\(String(format: "%.0f", threeBetPct))% 3-bet)"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                controls
                summary
                grid
                legend
                if mode.isDefending {
                    defenseCaveat
                }
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

            if mode.isDefending {
                defendingPositionControls
            } else {
                Picker("Position", selection: $position) {
                    ForEach(Position.allCases) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("positionPicker")
            }

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

    private var defendingPositionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(mode == .vsShove ? "Shover" : "Opener")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Opponent", selection: $opponentPosition) {
                    ForEach(Position.allCases) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("opponentPositionPicker")
                .onChange(of: opponentPosition) { _, newOpponent in
                    if heroPosition.actionOrderIndex <= newOpponent.actionOrderIndex {
                        heroPosition = .bigBlind
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("You")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("You", selection: $heroPosition) {
                    ForEach(validHeroPositions) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("heroPositionPicker")
            }
        }
    }

    private var summary: some View {
        Text(summaryText)
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
        let style = cellStyles[row][col]

        return Text(notation)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(style.color)
            .foregroundStyle(style.textColor)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .accessibilityIdentifier("cell-\(notation)")
    }

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach(mode.legendEntries, id: \.label) { entry in
                legendSwatch(color: entry.color, label: entry.label)
            }
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

    private var defenseCaveat: some View {
        Text(
            mode == .vsShove
            ? "Study aid, not solver output. Big-blind calls are this model's best-grounded numbers; every other caller here is a rougher approximation — see RANGES.md."
            : "Study aid, not solver output. Blind-defense shape is sourced; non-blind defenders and the 3-bet/call split are hand-tuned approximations — see RANGES.md."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .accessibilityIdentifier("defenseCaveatText")
    }
}

#Preview {
    NavigationStack {
        PreflopRangeView()
    }
}
