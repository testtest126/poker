import SwiftUI
import PokerKit

struct PushFoldTrainerView: View {
    @State private var spot = PushFoldSpot.random()
    @State private var answer: PushFoldAction?
    @State private var sessionCorrect = 0
    @State private var sessionTotal = 0

    private var decision: PushFoldDecision { spot.decision }
    private var isAnswered: Bool { answer != nil }
    private var isCorrect: Bool { answer == decision.action }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
        .navigationTitle("Push/Fold Trainer")
        .navigationBarTitleDisplayMode(.inline)
    }

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
        spot = PushFoldSpot.random()
        answer = nil
    }
}

private struct CardView: View {
    let card: Card

    private var isRed: Bool { card.suit == .hearts || card.suit == .diamonds }

    var body: some View {
        VStack(spacing: 2) {
            Text(card.rank.symbol)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(card.suit.symbol)
                .font(.system(size: 22))
        }
        .foregroundStyle(isRed ? Color.red : Color.primary)
        .frame(width: 64, height: 84)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
    }
}

#Preview {
    NavigationStack {
        PushFoldTrainerView()
    }
}
