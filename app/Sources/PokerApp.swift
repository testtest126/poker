import SwiftUI
import SwiftData

@main
struct PokerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: BankrollEntryRecord.self)
    }
}
