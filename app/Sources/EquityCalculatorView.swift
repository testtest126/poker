import SwiftUI
import PokerKit

/// Holds the in-flight/last equity calculation. A reference type on purpose: `calculate()`
/// kicks off background work whose completion callback needs to mutate state reliably after
/// `EquityCalculatorView` (a `View`, i.e. a *value type*) may have already been re-created
/// several times by SwiftUI. Capturing `self` for a struct across that async gap is a
/// documented footgun — the completion handler can end up writing into a stale copy that
/// never reaches the screen. A `@State`-held reference type has a single, stable identity
/// for the lifetime of the view, so this can't happen: whoever the closure's `self` is, it's
/// the same object the view is still observing when the closure runs.
@Observable
final class EquityCalculatorModel {
    private(set) var isCalculating = false
    private(set) var result: EquityResult?

    func calculate(hero: [HoleCards], villain: [HoleCards], board: [Card], iterations: Int) {
        isCalculating = true
        result = nil

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let computed = Equity.rangeVsRange(heroRange: hero, villainRange: villain, board: board, iterations: iterations)
            DispatchQueue.main.async { [self] in
                result = computed
                isCalculating = false
            }
        }
    }

    func clearResult() {
        result = nil
    }
}

/// Pick a hero hand class, a villain hand class, and an optional board; see win/tie/lose %.
///
/// Both hero and villain are entered as **canonical hand notation** ("AKs", "QQ", "72o") —
/// each expands to every concrete suit combo it represents (`Equity.expandCanonical`) and
/// equity is computed across all of them, exactly like `Equity.canonicalVsCanonical`. This
/// deliberately answers "hand class vs. hand class," the question players actually mean by
/// "what's my equity with AKs here" — not "what's the equity of this one specific pair of
/// suited cards," which `Equity.headsUp` can answer exactly but isn't what this screen is
/// for. See `ai-docs/EQUITY.md`'s "A subtlety: which suits?" section for why that
/// distinction matters.
///
/// Always uses Monte Carlo (`Equity.rangeVsRange`), never `Equity.headsUp`'s exact
/// enumeration — the exact preflop path takes on the order of minutes even in a release
/// build (see `EQUITY.md`'s performance note), which would hang this screen. 10,000
/// iterations keeps a tap-to-result under a few seconds; see `EQUITY.md` for the
/// resulting standard error.
struct EquityCalculatorView: View {
    private static let liveIterations = 10_000

    @State private var model = EquityCalculatorModel()
    @State private var heroNotation = "AKs"
    @State private var villainNotation = "QQ"
    @State private var street: Street = .preflop
    @State private var boardCards: [Card?] = Array(repeating: nil, count: 5)

    private var boardCardCount: Int {
        switch street {
        case .preflop: return 0
        case .flop: return 3
        case .turn: return 4
        case .river: return 5
        }
    }

    private var heroCombos: [HoleCards] { Equity.expandCanonical(Self.normalize(heroNotation)) }
    private var villainCombos: [HoleCards] { Equity.expandCanonical(Self.normalize(villainNotation)) }
    private var resolvedBoard: [Card] { Array(boardCards.prefix(boardCardCount).compactMap { $0 }) }

    /// Uppercases the rank characters but not a trailing suited/offsuit flag —
    /// `Equity.expandCanonical` requires a lowercase `s`/`o` (`"AKs"`, not `"AKS"`), so a
    /// blanket `.uppercased()` on user input would silently invalidate every suited/offsuit
    /// hand typed in any case other than already-correct.
    private static func normalize(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard trimmed.count == 3 else { return trimmed.uppercased() }
        return trimmed.prefix(2).uppercased() + trimmed.suffix(1).lowercased()
    }

    private var validationMessage: String? {
        if heroNotation.isEmpty { return nil }
        if heroCombos.isEmpty { return "Hero isn't a valid hand — try \"AKs\", \"QQ\", or \"72o\"." }
        if villainNotation.isEmpty { return nil }
        if villainCombos.isEmpty { return "Villain isn't a valid hand — try \"AKs\", \"QQ\", or \"72o\"." }
        if resolvedBoard.count != boardCardCount { return "Finish setting the board." }
        if Set(resolvedBoard).count != resolvedBoard.count { return "Board has a repeated card." }
        return nil
    }

    private var isReadyToCalculate: Bool {
        !heroCombos.isEmpty && !villainCombos.isEmpty
            && resolvedBoard.count == boardCardCount
            && Set(resolvedBoard).count == resolvedBoard.count
    }

    var body: some View {
        Form {
            Section("Hero") {
                TextField("e.g. AKs, QQ, 72o", text: $heroNotation)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("heroNotationField")
                    .onChange(of: heroNotation) { _, _ in model.clearResult() }
            }

            Section("Villain") {
                TextField("e.g. AKs, QQ, 72o", text: $villainNotation)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("villainNotationField")
                    .onChange(of: villainNotation) { _, _ in model.clearResult() }
            }

            Section("Board") {
                Picker("Street", selection: $street) {
                    Text("Preflop").tag(Street.preflop)
                    Text("Flop").tag(Street.flop)
                    Text("Turn").tag(Street.turn)
                    Text("River").tag(Street.river)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("streetPicker")
                .onChange(of: street) { _, _ in model.clearResult() }

                ForEach(0..<boardCardCount, id: \.self) { index in
                    BoardCardPickerRow(
                        label: "Card \(index + 1)",
                        card: Binding(
                            get: { boardCards[index] },
                            set: {
                                boardCards[index] = $0
                                model.clearResult()
                            }
                        )
                    )
                }
            }

            Section {
                Button {
                    model.calculate(hero: heroCombos, villain: villainCombos, board: resolvedBoard, iterations: Self.liveIterations)
                } label: {
                    HStack {
                        Spacer()
                        if model.isCalculating {
                            ProgressView()
                        } else {
                            Text("Calculate")
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isReadyToCalculate || model.isCalculating)
                .accessibilityIdentifier("calculateButton")

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let result = model.result {
                resultSection(result)
            }
        }
        .navigationTitle("Equity Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resultSection(_ result: EquityResult) -> some View {
        Section("Result") {
            resultRow(label: "Hero wins", value: result.winRate, tint: .green, identifier: "heroWinRate")
            resultRow(label: "Tie", value: result.tieRate, tint: .secondary, identifier: "tieRate")
            resultRow(label: "Villain wins", value: result.loseRate, tint: .red, identifier: "villainWinRate")
            Text("\(result.trials.formatted()) Monte Carlo simulations, fixed seed — same inputs always give the same result. Not a solver; see ai-docs/EQUITY.md.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("equityMethodText")
        }
    }

    private func resultRow(label: String, value: Double, tint: Color, identifier: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.1f%%", value * 100))
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(tint)
                .accessibilityIdentifier(identifier)
        }
    }
}

/// One board card: a rank menu and a suit menu that combine into a `Card?`. Clears back to
/// `nil` if either half is unset, rather than allowing a half-picked card to leak through.
private struct BoardCardPickerRow: View {
    let label: String
    @Binding var card: Card?

    @State private var rank: Rank?
    @State private var suit: Suit?

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Picker("Rank", selection: $rank) {
                Text("–").tag(Rank?.none)
                ForEach(Rank.allCases.reversed(), id: \.self) { r in
                    Text(r.symbol).tag(Rank?.some(r))
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("\(label)RankPicker")

            Picker("Suit", selection: $suit) {
                Text("–").tag(Suit?.none)
                ForEach(Suit.allCases, id: \.self) { s in
                    Text(s.symbol).tag(Suit?.some(s))
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("\(label)SuitPicker")
        }
        .onChange(of: rank) { _, _ in updateCard() }
        .onChange(of: suit) { _, _ in updateCard() }
        .onAppear {
            rank = card?.rank
            suit = card?.suit
        }
    }

    private func updateCard() {
        if let rank, let suit {
            card = Card(rank: rank, suit: suit)
        } else {
            card = nil
        }
    }
}

#Preview {
    NavigationStack {
        EquityCalculatorView()
    }
}
