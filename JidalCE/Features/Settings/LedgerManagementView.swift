import SwiftUI

struct LedgerManagementView: View {
    @Environment(AppState.self) private var appState
    @State private var name = ""
    @State private var icon = "💰"
    @State private var color = "blue"
    @State private var editingLedger: Ledger?

    var body: some View {
        List {
            Section("새 가계부") {
                TextField("이름", text: $name)
                TextField("아이콘", text: $icon)
                TextField("색상", text: $color)
                Button("가계부 추가") {
                    Task {
                        await appState.addLedger(name: name, icon: icon, color: color)
                        name = ""
                    }
                }
            }

            Section("가계부 목록") {
                ForEach(appState.ledgers) { ledger in
                    Button {
                        editingLedger = ledger
                    } label: {
                        HStack {
                            Text("\(ledger.icon) \(ledger.name)")
                            Spacer()
                            if appState.selectedLedgerName == ledger.name {
                                Text("선택됨")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("삭제", role: .destructive) {
                            Task { await appState.deleteLedger(ledger) }
                        }
                    }
                }
                .onMove { source, destination in
                    appState.moveLedgers(from: source, to: destination)
                }
            }
        }
        .navigationTitle("가계부 관리")
        .toolbar {
            EditButton()
        }
        .sheet(item: $editingLedger) { ledger in
            LedgerEditView(ledger: ledger)
        }
    }
}
