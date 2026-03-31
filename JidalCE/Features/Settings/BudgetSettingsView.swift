import SwiftUI

struct BudgetSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var monthlyLimit = ""
    @State private var categoryLimits: [String: String] = [:]

    var body: some View {
        Form {
            Section("월 총 예산") {
                TextField("월 총 예산", text: $monthlyLimit)
                    .keyboardType(.numberPad)
            }

            Section("카테고리별 예산") {
                ForEach(appState.categoryManager.categories, id: \.self) { category in
                    HStack {
                        Text(category)
                        Spacer()
                        TextField("0", text: Binding(
                            get: { categoryLimits[category, default: ""] },
                            set: { categoryLimits[category] = $0.filteredDigits }
                        ))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        Text("원")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("저장") {
                    guard let ledgerName = appState.selectedLedgerName else { return }
                    let budget = Budget(
                        monthlyLimit: Int(monthlyLimit) ?? 0,
                        categoryLimits: categoryLimits.compactMapValues { Int($0) }.filter { $0.value > 0 }
                    )
                    appState.budgetManager.save(budget, for: ledgerName)
                    appState.refreshBudget()
                }
            }
        }
        .navigationTitle("예산 관리")
        .onAppear {
            guard let ledgerName = appState.selectedLedgerName else { return }
            let budget = appState.budgetManager.budget(for: ledgerName)
            monthlyLimit = budget.monthlyLimit == 0 ? "" : String(budget.monthlyLimit)
            categoryLimits = budget.categoryLimits.mapValues(String.init)
        }
    }
}
