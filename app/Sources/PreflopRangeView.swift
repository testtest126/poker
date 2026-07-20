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

/// A cell's visual role. `.bountyOnly` only ever appears in Push/Fold mode with the bounty
/// overlay on — it marks a hand that folds in the base chip-EV model but shoves once the
/// bounty is accounted for, so the widening is visible directly on the grid rather than
/// only in the summary percentage.
private enum CellStyle {
    case aggressive
    case bountyOnly
    case fold

    var color: Color {
        switch self {
        case .aggressive: return .accentColor
        case .bountyOnly: return .orange
        case .fold: return Color(.secondarySystemBackground)
        }
    }

    var textColor: Color {
        switch self {
        case .aggressive, .bountyOnly: return .white
        case .fold: return .secondary
        }
    }
}

struct PreflopRangeView: View {
    @State private var mode: RangeMode = .pushFold
    @State private var position: Position = .utg
    @State private var effectiveStackBB: Double = RangeMode.pushFold.defaultStack

    // PKO bounty overlay — Push/Fold mode only (see BountyEquity/BOUNTY.md). Left off by
    // default so the base chip-EV grid is what a user sees unless they opt in.
    @State private var bountyEnabled = false
    @State private var bountyBB: Double = 20
    @State private var heroCoversVillain = true

    private var isBountyActive: Bool { mode == .pushFold && bountyEnabled }

    /// Whether each of the 169 grid cells is the "aggressive" action (shove, or open) for
    /// the current mode/position/stack, ignoring any bounty overlay — the base chip-EV
    /// grid `PushFoldRange`/`OpeningRange` would render on their own.
    private var baseIsAggressiveGrid: [[Bool]] {
        switch mode {
        case .pushFold:
            return PreflopGrid.decisions(position: position, effectiveStackBB: effectiveStackBB)
                .map { row in row.map { $0.action == .push } }
        case .opening:
            return PreflopGrid.openingDecisions(position: position, effectiveStackBB: effectiveStackBB)
                .map { row in row.map { $0.action == .raise } }
        }
    }

    /// Same shape, mapped through `BountyEquity` instead — `nil` unless the bounty overlay
    /// is actually active, so callers never pay for it otherwise.
    private var bountyIsAggressiveGrid: [[Bool]]? {
        guard isBountyActive else { return nil }
        return PreflopGrid.hands.map { row in
            row.map { hand in
                BountyEquity.decide(
                    hand: hand, position: position, effectiveStackBB: effectiveStackBB,
                    bountyBB: bountyBB, heroCoversVillain: heroCoversVillain
                ).action == .push
            }
        }
    }

    private var cellStyles: [[CellStyle]] {
        guard let bountyGrid = bountyIsAggressiveGrid else {
            return baseIsAggressiveGrid.map { row in row.map { $0 ? .aggressive : .fold } }
        }
        let baseGrid = baseIsAggressiveGrid
        return baseGrid.indices.map { row in
            baseGrid[row].indices.map { col in
                guard bountyGrid[row][col] else { return .fold }
                return baseGrid[row][col] ? .aggressive : .bountyOnly
            }
        }
    }

    /// Percentage of the 169 cells actually colored "aggressive" in the given grid — kept
    /// empirical (counted from the rendered grid) rather than read off
    /// `PushFoldRange.shovePercentage`/`OpeningRange.openPercentage` directly, so the
    /// summary text can never drift out of sync with what's on screen (Chen-score ties can
    /// make the exact count cross a percentile boundary slightly differently than the
    /// target percentage would suggest).
    private func percentage(of grid: [[Bool]]) -> Double {
        let flat = grid.flatMap { $0 }
        guard !flat.isEmpty else { return 0 }
        return Double(flat.filter { $0 }.count) / Double(flat.count) * 100
    }

    private var basePercentage: Double { percentage(of: baseIsAggressiveGrid) }
    private var bountyPercentage: Double { bountyIsAggressiveGrid.map(percentage(of:)) ?? basePercentage }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                controls
                summary
                grid
                legend
                if isBountyActive {
                    bountyCaveat
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

            if mode == .pushFold {
                bountyControls
            }
        }
    }

    private var bountyControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("PKO Bounty", isOn: $bountyEnabled)
                .accessibilityIdentifier("bountyToggle")

            if bountyEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Bounty")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(bountyBB)) bb")
                            .font(.headline)
                            .monospacedDigit()
                            .accessibilityIdentifier("bountyValue")
                    }
                    Slider(value: $bountyBB, in: 0...100, step: 1)
                        .accessibilityIdentifier("bountySlider")
                }

                Toggle("You cover villain", isOn: $heroCoversVillain)
                    .accessibilityIdentifier("heroCoversVillainToggle")
            }
        }
    }

    private var summary: some View {
        Group {
            if isBountyActive {
                Text("\(pct(basePercentage))\(mode.summarySuffix) — \(pct(bountyPercentage)) with bounty")
            } else {
                Text("\(pct(basePercentage))\(mode.summarySuffix)")
            }
        }
        .font(.subheadline.bold())
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("shovePercentageText")
    }

    private func pct(_ value: Double) -> String { String(format: "%.0f", value) }

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
            legendSwatch(color: .accentColor, label: mode.actionLabel)
            if isBountyActive {
                legendSwatch(color: .orange, label: "\(mode.actionLabel) (bounty only)")
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

    private var bountyCaveat: some View {
        Text(
            heroCoversVillain
            ? "Study aid, not solver output. Chip-EV widened for a collectible bounty only — no ICM, no being-covered risk. See ai-docs/BOUNTY.md."
            : "You don't cover villain here, so the bounty isn't collectible on this shove — this grid matches the base (no-bounty) range."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .accessibilityIdentifier("bountyCaveatText")
    }
}

#Preview {
    NavigationStack {
        PreflopRangeView()
    }
}
