import SwiftUI
import PokerKit

/// Holds the in-flight/last Omaha equity calculation — a reference type held via `@State`,
/// same async-safety rationale as `EquityCalculatorModel` (see its doc comment): a `View` is
/// a value type SwiftUI can recreate mid-calculation, so background work needs a stable
/// reference-type home to write its result into.
@Observable
final class OmahaEquityCalculatorModel {
    private(set) var isCalculating = false
    private(set) var result: EquityResult?

    func calculate(hero: OmahaHoleCards, villain: OmahaHoleCards, board: [Card], mode: EquityMode, iterations: Int) {
        isCalculating = true
        result = nil

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let computed: EquityResult
            switch mode {
            case .fast:
                computed = OmahaEquity.monteCarlo(hero: [hero], villain: [villain], board: board, iterations: iterations)
            case .precise:
                computed = OmahaEquity.headsUp(hero: hero, villain: villain, board: board)
            }
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

/// A deliberately minimal Omaha/PLO equity screen — Phase 1's app-facing slice (see
/// `ai-docs/OMAHA.md`). Hero and villain are entered as **explicit 4-card notation**
/// (`"AsKsAhKh"`), not a hand-class shorthand the way `EquityCalculatorView` accepts "AKs" —
/// Omaha has no standardized canonical-hand-class notation to expand from (see
/// `OmahaHoleCards.notation`'s doc comment), and inventing one is exactly the kind of
/// hand-strength judgment call deferred to Phase 2. The board is entered the same way, as a
/// single notation string, rather than per-card rank/suit menu pickers — a disclosed scope
/// cut to keep this screen small; `EquityCalculatorView`'s `BoardCardPickerRow` remains the
/// richer NLHE experience.
///
/// **No Precise (exact) mode preflop** — `OmahaEquity.headsUp` preflop is roughly 2x the cost
/// of Hold'em's own already-slow (several-minute) preflop exact case (see `OMAHA.md`'s
/// performance note); offering it here would hang the UI. Postflop, exact is offered exactly
/// like `EquityCalculatorView` does — **but flop-exact specifically measured close to (and,
/// on one run, over) 30 seconds** in a debug build on the iOS Simulator, meaningfully slower
/// than Hold'em's own flop-exact mode (a cheaper computation — 42 evaluations per board vs.
/// Omaha's 120). Turn and river exact are fast (≤40 completions, or 0 for a given river).
/// Flop-exact is left enabled here (not blocked) since it does eventually complete, but treat
/// it as "tractable, not instant" rather than assuming it behaves like Hold'em's version.
struct OmahaEquityCalculatorView: View {
    /// Not independently measured on an iOS Simulator (unlike `EquityCalculatorView`'s own
    /// 10,000, which was) — extrapolated from that measured figure, scaled down by Omaha
    /// Monte Carlo's roughly ~2.9x higher per-trial cost (120 5-card evaluations per trial
    /// vs. Hold'em Monte Carlo's ~42), to keep a similar tap-to-result wall-clock time.
    /// **Flagged as an estimate, not a verified one** — if this feels slow on-device, lower
    /// it further; see `OMAHA.md`.
    private static let liveIterations = 3_000

    @State private var model = OmahaEquityCalculatorModel()
    @State private var heroNotation = "AsKsAhKh"
    @State private var villainNotation = "8s7s6h5h"
    @State private var street: Street = .preflop
    @State private var boardNotation = ""
    @State private var mode: EquityMode = .fast

    private var boardCardCount: Int {
        switch street {
        case .preflop: return 0
        case .flop: return 3
        case .turn: return 4
        case .river: return 5
        }
    }

    /// Uppercases rank characters, lowercases suit characters, for every 2-character card
    /// token in `input` — the notation equivalent of `EquityCalculatorView.normalize(_:)`,
    /// generalized to any even-length run of tokens (a 4-card hole hand or an N-card board).
    private static func normalizeCardTokens(_ input: String) -> String {
        let chars = Array(input.trimmingCharacters(in: .whitespaces))
        guard chars.count.isMultiple(of: 2) else { return String(chars) }
        var result = ""
        var i = 0
        while i + 1 < chars.count {
            result += chars[i].uppercased()
            result += chars[i + 1].lowercased()
            i += 2
        }
        return result
    }

    private var heroHand: OmahaHoleCards? { OmahaHoleCards(canonical: Self.normalizeCardTokens(heroNotation)) }
    private var villainHand: OmahaHoleCards? { OmahaHoleCards(canonical: Self.normalizeCardTokens(villainNotation)) }

    /// `nil` when the board notation doesn't parse to exactly `boardCardCount` cards; `[]`
    /// (a valid, complete, zero-card board) at preflop.
    private var resolvedBoard: [Card]? {
        guard boardCardCount > 0 else { return [] }
        let normalized = Self.normalizeCardTokens(boardNotation)
        guard normalized.count == boardCardCount * 2 else { return nil }
        var cards: [Card] = []
        let chars = Array(normalized)
        var i = 0
        while i + 1 < chars.count {
            guard let card = Card(notation: String(chars[i...(i + 1)])) else { return nil }
            cards.append(card)
            i += 2
        }
        return cards
    }

    private var validationMessage: String? {
        if !heroNotation.isEmpty, heroHand == nil { return "Hero isn't a valid 4-card hand — try \"AsKsAhKh\"." }
        if !villainNotation.isEmpty, villainHand == nil { return "Villain isn't a valid 4-card hand — try \"8s7s6h5h\"." }
        if boardCardCount > 0, resolvedBoard == nil { return "Finish setting the board (\(boardCardCount) cards)." }
        if let hero = heroHand, let villain = villainHand, let board = resolvedBoard {
            let all = hero.cards + villain.cards + board
            if Set(all).count != all.count { return "Hero, villain, and the board can't share a card." }
        }
        return nil
    }

    private var isReadyToCalculate: Bool {
        guard let hero = heroHand, let villain = villainHand, let board = resolvedBoard else { return false }
        let all = hero.cards + villain.cards + board
        return Set(all).count == all.count
    }

    var body: some View {
        Form {
            Section("Hero") {
                TextField("e.g. AsKsAhKh", text: $heroNotation)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("omahaHeroNotationField")
                    .onChange(of: heroNotation) { _, _ in model.clearResult() }
            }

            Section("Villain") {
                TextField("e.g. 8s7s6h5h", text: $villainNotation)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("omahaVillainNotationField")
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
                .accessibilityIdentifier("omahaStreetPicker")
                .onChange(of: street) { _, newStreet in
                    model.clearResult()
                    if newStreet == .preflop { mode = .fast }
                }

                if boardCardCount > 0 {
                    TextField("e.g. Kd7h2c", text: $boardNotation)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("omahaBoardNotationField")
                        .onChange(of: boardNotation) { _, _ in model.clearResult() }
                }
            }

            Section("Mode") {
                Picker("Mode", selection: $mode) {
                    ForEach(EquityMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(street == .preflop)
                .accessibilityIdentifier("omahaEquityModePicker")
                .onChange(of: mode) { _, _ in model.clearResult() }

                if street == .preflop {
                    Text("Precise needs a board — exact Omaha enumeration preflop takes upwards of 10 minutes. Fast (Monte Carlo) is accurate enough for study purposes; see ai-docs/OMAHA.md.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    guard let hero = heroHand, let villain = villainHand, let board = resolvedBoard else { return }
                    model.calculate(hero: hero, villain: villain, board: board, mode: mode, iterations: Self.liveIterations)
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
                .accessibilityIdentifier("omahaCalculateButton")

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
        .navigationTitle("Omaha Equity")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resultSection(_ result: EquityResult) -> some View {
        Section("Result") {
            resultRow(label: "Hero wins", value: result.winRate, tint: .green, identifier: "omahaHeroWinRate")
            resultRow(label: "Tie", value: result.tieRate, tint: .secondary, identifier: "omahaTieRate")
            resultRow(label: "Villain wins", value: result.loseRate, tint: .red, identifier: "omahaVillainWinRate")
            Text(methodCaption(for: result))
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("omahaEquityMethodText")
        }
    }

    private func methodCaption(for result: EquityResult) -> String {
        if result.isExact {
            return "Exact — every legal 2-hole/3-board combination enumerated across every matching board, zero sampling error. Not a solver; see ai-docs/OMAHA.md."
        }
        return "\(result.trials.formatted()) Monte Carlo simulations, fixed seed — same inputs always give the same result. Not a solver; see ai-docs/OMAHA.md."
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

#Preview {
    NavigationStack {
        OmahaEquityCalculatorView()
    }
}
