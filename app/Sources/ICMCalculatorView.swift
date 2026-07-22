import SwiftUI
import PokerKit

/// One editable stack row. Stack is kept as text (not `Double`) so a field can sit briefly
/// invalid (empty, mid-edit) without losing what the user typed — `ICMCalculatorView` only
/// computes once every row parses.
private struct StackEntry: Identifiable {
    let id = UUID()
    var name: String
    var stack: String
}

/// Enter chip stacks and a payout structure, see every seat's exact ICM $ equity —
/// `ICM.equities` is a pure, fast function (no async dispatch needed, unlike
/// `EquityCalculatorView`'s Monte Carlo work), so this view recomputes live on every edit
/// rather than needing a Calculate button.
///
/// Deliberately scoped to just the calculator: `ICMRiskPremium` (the ICM-adjusted
/// required-equity-to-call helper — see `ai-docs/ICM.md`) is implemented and tested but has
/// no dedicated screen yet; wiring a shove/call ICM trainer around it is a natural follow-up,
/// not part of this view.
struct ICMCalculatorView: View {
    @State private var stacks: [StackEntry] = [
        StackEntry(name: "Seat 1", stack: "5000"),
        StackEntry(name: "Seat 2", stack: "3000"),
        StackEntry(name: "Seat 3", stack: "2000"),
    ]
    @State private var payouts: [String] = ["500", "300", "200"]

    private var parsedStacks: [Double]? {
        let values = stacks.map { Double($0.stack) }
        guard values.allSatisfy({ $0 != nil && $0! > 0 }) else { return nil }
        return values.map { $0! }
    }

    private var parsedPayouts: [Double]? {
        let values = payouts.map { Double($0) }
        guard values.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        return values.map { $0! }
    }

    private var equities: [Double]? {
        guard let parsedStacks, !parsedStacks.isEmpty, let parsedPayouts else { return nil }
        return ICM.equities(stacks: parsedStacks, payouts: parsedPayouts)
    }

    private var validationMessage: String? {
        if stacks.isEmpty { return "Add at least one stack." }
        if parsedStacks == nil { return "Every stack needs a positive number." }
        if parsedPayouts == nil { return "Every payout needs a number (0 or more)." }
        return nil
    }

    var body: some View {
        Form {
            Section("Stacks") {
                ForEach($stacks) { $entry in
                    HStack {
                        TextField("Name", text: $entry.name)
                            .frame(maxWidth: .infinity)
                        TextField("Chips", text: $entry.stack)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .accessibilityIdentifier("stackField-\(entry.name)")
                    }
                }
                .onDelete { stacks.remove(atOffsets: $0) }

                Button("Add Player") {
                    stacks.append(StackEntry(name: "Seat \(stacks.count + 1)", stack: ""))
                }
                .accessibilityIdentifier("addPlayerButton")
            }

            Section("Payouts") {
                ForEach(Array(payouts.enumerated()), id: \.offset) { index, _ in
                    HStack {
                        Text(placeLabel(index))
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .leading)
                        TextField("Amount", text: $payouts[index])
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("payoutField-\(index)")
                    }
                }
                .onDelete { payouts.remove(atOffsets: $0) }

                Button("Add Place") {
                    payouts.append("")
                }
                .accessibilityIdentifier("addPlaceButton")
            }

            if let equities, let parsedStacks {
                resultSection(equities: equities, stacks: parsedStacks)
            } else if let validationMessage {
                Section {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("icmValidationText")
                }
            }
        }
        .navigationTitle("ICM Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func placeLabel(_ index: Int) -> String {
        switch index {
        case 0: return "1st"
        case 1: return "2nd"
        case 2: return "3rd"
        default: return "\(index + 1)th"
        }
    }

    private func resultSection(equities: [Double], stacks parsedStacks: [Double]) -> some View {
        let totalChips = parsedStacks.reduce(0, +)
        return Section("Equity") {
            ForEach(stacks.indices, id: \.self) { index in
                let stack = parsedStacks[index]
                let equity = equities[index]
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(stacks[index].name)
                            .font(.headline)
                        Spacer()
                        Text(currency(equity))
                            .font(.headline)
                            .monospacedDigit()
                            .accessibilityIdentifier("equityValue-\(stacks[index].name)")
                    }
                    Text("\(percent(stack / totalChips)) of chips — \(currency(equity / stack))/chip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Total")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currency(equities.reduce(0, +)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityIdentifier("icmTotalEquity")
            }
            .font(.caption)

            Text("Exact math (Malmuth-Harville ICM), not a solver or a hand-tuned estimate — see ai-docs/ICM.md.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("icmCaveatText")
        }
    }

    private func currency(_ value: Double) -> String {
        "$" + String(format: "%.2f", value)
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}

#Preview {
    NavigationStack {
        ICMCalculatorView()
    }
}
