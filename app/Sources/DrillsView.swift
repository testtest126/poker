import SwiftUI
import SwiftData
import PokerKit

/// The push/fold trainer, but weighted toward the position/stack region where the
/// user's own imported hands show them deviating from `PushFoldRange` most. Falls back
/// to the same fully-random practice as the plain trainer when there isn't enough
/// imported data to identify a leak.
struct DrillsView: View {
    @Query private var records: [HandRecord]

    @State private var focus: DrillFocus?
    @State private var hasImportedHands = false
    @State private var hasComputedFocus = false

    @State private var spot = PushFoldSpot.random()
    @State private var answer: PushFoldAction?
    @State private var sessionCorrect = 0
    @State private var sessionTotal = 0

    private var decision: PushFoldDecision { spot.decision }
    private var isCorrect: Bool { answer == decision.action }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                focusHeader

                scoreHeader

                spotCard

                if let answer {
                    feedback(for: answer)
                } else {
                    answerButtons
                }
            }
            .padding()
        }
        .navigationTitle("Practice Your Leaks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: computeFocusIfNeeded)
    }

    // MARK: - Focus

    private func computeFocusIfNeeded() {
        guard !hasComputedFocus else { return }
        hasComputedFocus = true

        let parsedHands = records.compactMap { HandHistoryParser.parse($0.rawText).hands.first }
        hasImportedHands = !parsedHands.isEmpty
        if hasImportedHands {
            focus = DrillGenerator.focus(from: LeakAnalysisEngine.analyze(hands: parsedHands))
        }
        spot = DrillGenerator.spot(focus: focus)
    }

    private var focusHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: focusIconName)
                .foregroundStyle(focusIconTint)
            Text(focusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("drillFocusHeader")
    }

    private var focusMessage: String {
        if let focus {
            return focus.explanation
        } else if hasImportedHands {
            return "No push/fold deviations found in your imported hands yet — showing general practice."
        } else {
            return "Import hand histories to personalize this drill to your own leaks. Showing general practice for now."
        }
    }

    private var focusIconName: String {
        focus != nil ? "target" : (hasImportedHands ? "checkmark.seal" : "info.circle")
    }

    private var focusIconTint: Color {
        focus != nil ? .orange : (hasImportedHands ? .green : .secondary)
    }

    // MARK: - Session

    private var scoreHeader: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(sessionCorrect) / \(sessionTotal) correct")
                    .font(.headline)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Accuracy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(accuracyText)
                    .font(.headline)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var accuracyText: String {
        guard sessionTotal > 0 else { return "—" }
        return String(format: "%.0f%%", Double(sessionCorrect) / Double(sessionTotal) * 100)
    }

    private var spotCard: some View {
        VStack(spacing: 16) {
            Text("Unopened — folds to you")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 32) {
                VStack {
                    Text(spot.position.rawValue)
                        .font(.title)
                        .bold()
                    Text(spot.position.fullName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(spot.effectiveStackBB) bb")
                        .font(.title)
                        .bold()
                    Text("effective stack")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                CardView(card: spot.hand.first)
                CardView(card: spot.hand.second)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var answerButtons: some View {
        HStack(spacing: 16) {
            Button {
                submit(.fold)
            } label: {
                Text("Fold")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)
            .tint(.gray)

            Button {
                submit(.push)
            } label: {
                Text("Push")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }

    private func feedback(for answer: PushFoldAction) -> some View {
        VStack(spacing: 16) {
            Label(
                isCorrect ? "Correct" : "Incorrect",
                systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.title2.bold())
            .foregroundStyle(isCorrect ? .green : .red)

            if !isCorrect {
                Text("Correct play: \(decision.action.rawValue)")
                    .font(.headline)
            }

            Text(decision.reasoning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Next Hand") {
                nextHand()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func submit(_ chosen: PushFoldAction) {
        answer = chosen
        sessionTotal += 1
        if chosen == decision.action {
            sessionCorrect += 1
        }
    }

    private func nextHand() {
        spot = DrillGenerator.spot(focus: focus)
        answer = nil
    }
}

#Preview {
    NavigationStack {
        DrillsView()
    }
    .modelContainer(for: HandRecord.self, inMemory: true)
}
