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
                case .preflopRanges:
                    PreflopRangeView()
                case .pushFold:
                    PushFoldTrainerView()
                case .bankroll:
                    BankrollTrackerView()
                case .handHistoryImport:
                    HandHistoryImportView()
                case .drills:
                    DrillsView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
