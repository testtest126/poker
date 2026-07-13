import SwiftUI
import PokerKit

struct PreflopRangeView: View {
    @State private var position: Position = .utg
    @State private var effectiveStackBB: Double = 10

    private var decisions: [[PushFoldDecision]] {
        PreflopGrid.decisions(position: position, effectiveStackBB: effectiveStackBB)
    }

    private var shovePercentage: Double {
        let total = decisions.reduce(0) { $0 + $1.count }
        let shoves = decisions.reduce(0) { $0 + $1.filter { $0.action == .push }.count }
        return Double(shoves) / Double(total) * 100
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
                Slider(value: $effectiveStackBB, in: 1...20, step: 1)
                    .accessibilityIdentifier("stackSlider")
            }
        }
    }

    private var summary: some View {
        Text("\(String(format: "%.0f", shovePercentage))% of hands")
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
        let decision = decisions[row][col]
        let notation = PreflopGrid.notation(row: row, col: col)
        let isShove = decision.action == .push

        return Text(notation)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(isShove ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundStyle(isShove ? Color.white : Color.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .accessibilityIdentifier("cell-\(notation)")
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendSwatch(color: .accentColor, label: "Shove")
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
