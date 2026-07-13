import SwiftUI
import PokerKit

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List(StudyTool.allCases) { tool in
                NavigationLink(value: tool) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tool.title)
                            .font(.headline)
                        Text(tool.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Poker Study")
            .navigationDestination(for: StudyTool.self) { tool in
                switch tool {
                case .pushFold:
                    PushFoldTrainerView()
                case .bankroll:
                    BankrollTrackerView()
                default:
                    ComingSoonView(tool: tool)
                }
            }
        }
    }
}

private struct ComingSoonView: View {
    let tool: StudyTool

    var body: some View {
        VStack(spacing: 12) {
            Text(tool.title)
                .font(.title2)
                .bold()
            Text(tool.summary)
                .foregroundStyle(.secondary)
            Text("Coming soon")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .navigationTitle(tool.title)
    }
}

#Preview {
    ContentView()
}
