import SwiftUI
import PokerKit

/// Pick a `GameFormat`, see (and adjust) the sensible starting defaults it seeds — effective
/// stack, PKO bounty, and ICM awareness — the same three parameters `PreflopRangeView`,
/// `BountyEquity`, and `ICMRiskPremium` already take.
///
/// **Deliberately self-contained, not a retrofit of every other screen.** Each of those
/// screens already manages its own independent state (`PreflopRangeView`'s `RangeMode`
/// already picks its own default stack per mode, `EquityCalculatorView`/`ICMCalculatorView`
/// have their own inputs entirely) — reaching into all of them to consume a single global
/// "current format" would entangle this defaults-only layer with state management this
/// project didn't build with a shared-format-source in mind. This view demonstrates and lets
/// a user *preview* what a format seeds — selecting a format resets the fields below to that
/// format's `GameFormatProfile` defaults, exactly the "seed, don't mutate" contract
/// `GameFormat.swift`'s doc comment describes — without silently reaching into and changing
/// other screens' independently-held state. Wiring a shared format selection into those
/// screens directly is a natural follow-up, not done here — see `ai-docs/FORMATS.md`.
struct GameFormatView: View {
    @State private var format: GameFormat = .mttRegular
    @State private var stackBB: Double
    @State private var bountyEnabled: Bool
    @State private var bountyFraction: Double
    @State private var icmEnabled: Bool

    init() {
        let profile = GameFormat.mttRegular.profile
        _stackBB = State(initialValue: profile.defaultStackBB)
        _bountyEnabled = State(initialValue: profile.bountyEnabled)
        _bountyFraction = State(initialValue: profile.defaultBountyFractionOfStartingStack ?? 0.33)
        _icmEnabled = State(initialValue: profile.icmEnabled)
    }

    private var profile: GameFormatProfile { format.profile }

    var body: some View {
        Form {
            Section("Format") {
                Picker("Format", selection: $format) {
                    ForEach(GameFormat.allCases) { format in
                        Text(format.profile.title).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("gameFormatPicker")
                .onChange(of: format) { _, newFormat in applyDefaults(for: newFormat) }

                Text(profile.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("gameFormatSummaryText")
            }

            Section("Seeded Defaults") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Effective Stack")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(stackBB)) bb")
                            .font(.headline)
                            .monospacedDigit()
                            .accessibilityIdentifier("gameFormatStackValue")
                    }
                    Slider(value: $stackBB, in: 1...200, step: 1)
                        .accessibilityIdentifier("gameFormatStackSlider")
                }

                Toggle("PKO Bounty", isOn: $bountyEnabled)
                    .accessibilityIdentifier("gameFormatBountyToggle")

                if bountyEnabled {
                    HStack {
                        Text("Bounty (% of stack)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(bountyFraction * 100))%")
                            .font(.headline)
                            .monospacedDigit()
                            .accessibilityIdentifier("gameFormatBountyValue")
                    }
                    Slider(value: $bountyFraction, in: 0...1, step: 0.01)
                        .accessibilityIdentifier("gameFormatBountySlider")
                }

                Toggle("ICM-Aware", isOn: $icmEnabled)
                    .accessibilityIdentifier("gameFormatICMToggle")

                if icmEnabled {
                    HStack {
                        Text("ICM Emphasis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(icmEmphasisLabel(profile.icmWeight))
                            .font(.headline)
                            .accessibilityIdentifier("gameFormatICMWeightText")
                    }
                }

                if let speed = profile.speed {
                    HStack {
                        Text("Speed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(speed.rawValue.capitalized)
                            .accessibilityIdentifier("gameFormatSpeedText")
                    }
                }
            }

            Section {
                Text("Sensible chosen defaults, not solver output or a rule — adjust anything above freely. See ai-docs/FORMATS.md for the rationale behind every value.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("gameFormatCaveatText")
            }
        }
        .navigationTitle("Game Format")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func applyDefaults(for format: GameFormat) {
        let profile = format.profile
        stackBB = profile.defaultStackBB
        bountyEnabled = profile.bountyEnabled
        bountyFraction = profile.defaultBountyFractionOfStartingStack ?? 0.33
        icmEnabled = profile.icmEnabled
    }

    private func icmEmphasisLabel(_ weight: Double) -> String {
        switch weight {
        case ..<0.01: return "None"
        case ..<0.45: return "Low"
        case ..<0.65: return "Moderate"
        case ..<0.85: return "High"
        default: return "Very High"
        }
    }
}

#Preview {
    NavigationStack {
        GameFormatView()
    }
}
