import SwiftUI

let ledgerIcons = ["💰", "🏠", "✈️", "🚗", "🎓", "💊", "🛒", "👶", "🐶", "🎮", "📱", "💳"]

enum LedgerColor: String, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        }
    }
}

struct LedgerEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var name: String
    @State private var icon: String
    @State private var color: String
    let ledger: Ledger

    init(ledger: Ledger) {
        self.ledger = ledger
        _name = State(initialValue: ledger.name)
        _icon = State(initialValue: ledger.icon)
        _color = State(initialValue: ledger.color)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("이름", text: $name)

                Picker("아이콘", selection: $icon) {
                    ForEach(ledgerIcons, id: \.self) { icon in
                        Text(icon).tag(icon)
                    }
                }

                Picker("색상", selection: $color) {
                    ForEach(LedgerColor.allCases, id: \.rawValue) { preset in
                        HStack {
                            Circle().fill(preset.color).frame(width: 12, height: 12)
                            Text(preset.rawValue)
                        }
                        .tag(preset.rawValue)
                    }
                }

                LabeledContent("통화", value: ledger.currency)
            }
            .navigationTitle("가계부 편집")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task {
                            await appState.updateLedger(ledger, name: name, icon: icon, color: color)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
