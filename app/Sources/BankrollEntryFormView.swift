import SwiftUI
import PokerKit

/// Add/edit form for a single bankroll session. Pass an existing `BankrollEntry`
/// to edit it in place, or nil to create a new one.
struct BankrollEntryFormView: View {
    let existingEntry: BankrollEntry?
    let onSave: (BankrollEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var tournamentName: String
    @State private var sessionType: SessionType
    @State private var buyIn: Decimal?
    @State private var cash: Decimal?
    @State private var notes: String

    init(existingEntry: BankrollEntry? = nil, onSave: @escaping (BankrollEntry) -> Void) {
        self.existingEntry = existingEntry
        self.onSave = onSave
        _date = State(initialValue: existingEntry?.date ?? .now)
        _tournamentName = State(initialValue: existingEntry?.tournamentName ?? "")
        _sessionType = State(initialValue: existingEntry?.sessionType ?? .tournament)
        _buyIn = State(initialValue: existingEntry?.buyIn)
        _cash = State(initialValue: existingEntry?.cash ?? 0)
        _notes = State(initialValue: existingEntry?.notes ?? "")
    }

    private var isValid: Bool {
        !tournamentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && buyIn != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    TextField("Name", text: $tournamentName)
                    Picker("Type", selection: $sessionType) {
                        ForEach(SessionType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Result") {
                    TextField("Buy-in", value: $buyIn, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Cash-out", value: $cash, format: .number)
                        .keyboardType(.decimalPad)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(existingEntry == nil ? "Add Session" : "Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        guard let buyIn else { return }
        let entry = BankrollEntry(
            id: existingEntry?.id ?? UUID(),
            date: date,
            tournamentName: tournamentName.trimmingCharacters(in: .whitespacesAndNewlines),
            sessionType: sessionType,
            buyIn: buyIn,
            cash: cash ?? 0,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSave(entry)
        dismiss()
    }
}

#Preview {
    BankrollEntryFormView { _ in }
}
