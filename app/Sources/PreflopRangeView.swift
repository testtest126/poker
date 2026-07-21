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

/// A cell's visual role — collapses every mode's distinct action types (push/raise/call/
/// 3-bet/fold), plus the Push/Fold bounty overlay, down to what the grid actually needs to
/// render. `.secondary` is only ever produced by `.vsOpen` ("call" as distinct from
/// "3-bet"); `.bountyOnly` is only ever produced by the Push/Fold bounty overlay (a hand
/// that folds in the base chip-EV model but shoves once the bounty is accounted for) — the
/// two never appear together, since the bounty overlay only exists in Push/Fold mode.
private enum CellStyle {
    case primary
    case secondary
    case bountyOnly
    case fold

    var color: Color {
        switch self {
        case .primary: return .accentColor
        case .secondary: return .teal
        case .bountyOnly: return .orange
        case .fold: return Color(.secondarySystemBackground)
        }
    }

    var textColor: Color {
        switch self {
        case .primary, .secondary, .bountyOnly: return .white
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

    // PKO bounty overlay — Push/Fold mode only (see BountyEquity/BOUNTY.md). Left off by
    // default so the base chip-EV grid is what a user sees unless they opt in.
    @State private var bountyEnabled = false
    @State private var bountyBB: Double = 20
    @State private var heroCoversVillain = true

    private var isBountyActive: Bool { mode == .pushFold && bountyEnabled }

    /// `DefendingPosition`s that could plausibly be facing `opponentPosition` — anyone who
    /// acts after them at an unopened table. The big blind is always valid, so it's a safe
    /// fallback default no matter what `opponentPosition` is.
    private var validHeroPositions: [DefendingPosition] {
        DefendingPosition.allCases.filter { $0.actionOrderIndex > opponentPosition.actionOrderIndex }
    }

    /// Whether each of the 169 grid cells is `PushFoldRange`'s own push/fold action —
    /// ignoring any bounty overlay. Only actually used in Push/Fold mode, but cheap enough
    /// (169 cells) that computing it unconditionally isn't worth guarding.
    private var baseIsAggressiveGrid: [[Bool]] {
        PreflopGrid.decisions(position: position, effectiveStackBB: effectiveStackBB)
            .map { row in row.map { $0.action == .push } }
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
        if let bountyGrid = bountyIsAggressiveGrid {
            let baseGrid = baseIsAggressiveGrid
            return baseGrid.indices.map { row in
                baseGrid[row].indices.map { col in
                    guard bountyGrid[row][col] else { return .fold }
                    return baseGrid[row][col] ? .primary : .bountyOnly
                }
            }
        }

        switch mode {
        case .pushFold:
            return baseIsAggressiveGrid.map { row in row.map { $0 ? .primary : .fold } }
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

    /// Percentage of the 169 cells actually flagged `true` in the given grid — kept
    /// empirical (counted from the same grid that drives rendering) rather than read off a
    /// model's raw percentage output directly, so the summary text can never drift out of
    /// sync with what's on screen (Chen-score ties can make the exact count cross a
    /// percentile boundary slightly differently than a target percentage would suggest).
    private func percentage(of grid: [[Bool]]) -> Double {
        let flat = grid.flatMap { $0 }
        guard !flat.isEmpty else { return 0 }
        return Double(flat.filter { $0 }.count) / Double(flat.count) * 100
    }

    private var summaryText: String {
        if isBountyActive {
            let base = percentage(of: baseIsAggressiveGrid)
            let bounty = bountyIsAggressiveGrid.map(percentage(of:)) ?? base
            return "\(pct(base))% of hands to shove — \(pct(bounty))% with bounty"
        }

        let flat = cellStyles.flatMap { $0 }
        guard !flat.isEmpty else { return "" }
        let total = Double(flat.count)
        let defendCount = flat.filter { $0 != .fold }.count
        let defendPct = Double(defendCount) / total * 100

        switch mode {
        case .pushFold: return "\(pct(defendPct))% of hands to shove"
        case .opening: return "\(pct(defendPct))% of hands to open"
        case .vsShove: return "\(pct(defendPct))% of hands to call"
        case .vsOpen:
            let threeBetCount = flat.filter { $0 == .primary }.count
            let threeBetPct = Double(threeBetCount) / total * 100
            return "\(pct(defendPct))% of hands to defend "
                + "(\(pct(threeBetPct))% 3-bet)"
        }
    }

    private func pct(_ value: Double) -> String { String(format: "%.0f", value) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                controls
                summary
                grid
                legend
                if mode.isDefending {
                    defenseCaveat
                } else if isBountyActive {
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
            if isBountyActive {
                legendSwatch(color: .orange, label: "Shove (bounty only)")
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
