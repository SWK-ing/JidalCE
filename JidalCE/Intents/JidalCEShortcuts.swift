import AppIntents

struct JidalCEShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Open \(.applicationName) to record an expense",
                "Use \(.applicationName) to add an expense",
                "In \(.applicationName), save expense"
            ],
            shortTitle: "지출 기록",
            systemImageName: "won.circle"
        )
        AppShortcut(
            intent: UndoLastTransactionIntent(),
            phrases: [
                "Undo last transaction in \(.applicationName)",
                "Delete last record in \(.applicationName)"
            ],
            shortTitle: "마지막 거래 취소",
            systemImageName: "arrow.uturn.backward"
        )
    }
}
