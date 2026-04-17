import SwiftUI

struct LedgerManagementView: View {
    @Environment(AppState.self) private var appState
    @State private var name = ""
    @State private var icon = "wonsign.circle.fill"
    @State private var color = "blue"
    @State private var currency = "KRW"
    @State private var editingLedger: Ledger?

    var body: some View {
        List {
            Section("새 가계부") {
                TextField("이름", text: $name)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(ledgerIcons, id: \.self) { iconOption in
                        Button {
                            icon = iconOption
                        } label: {
                            LedgerIconView(icon: iconOption, color: icon == iconOption ? .accentColor : .secondary)
                                .font(.title2)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(icon == iconOption ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                TextField("색상", text: $color)
                Picker("통화", selection: $currency) {
                    ForEach(supportedLedgerCurrencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                Button("가계부 추가") {
                    Task {
                        await appState.addLedger(name: name, icon: icon, color: color, currency: currency)
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
                            LedgerLabelView(name: ledger.name, icon: ledger.icon)
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
