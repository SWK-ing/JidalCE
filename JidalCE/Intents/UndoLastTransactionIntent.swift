import AppIntents

struct UndoLastTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "마지막 거래 취소"
    static var description = IntentDescription("가장 최근에 기록한 거래를 삭제합니다")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await run()
        return .result(dialog: IntentDialog(stringLiteral: message))
    }

    @MainActor
    private func run() throws -> String {
        let store = CalendarStore.shared
        let groupRepository = GroupRepository(store: store)
        let historyRepository = HistoryRepository(store: store)
        let transactionRepository = TransactionRepository(store: store, historyRepository: historyRepository)
        let groups = groupRepository.fetchGroups()
        let groupID = UserDefaults.standard.string(forKey: "selectedGroupIdentifier")
        guard let group = groups.first(where: { $0.id == groupID }) ?? groups.first else {
            return "선택된 그룹이 없습니다."
        }

        let ledgerName = UserDefaults.standard.string(forKey: "selectedLedgerName") ?? "생활비"
        let transactions = try transactionRepository.fetchTransactions(
            from: Date().addingMonth(-1).startOfMonth,
            to: Date().endOfDay,
            ledgerName: ledgerName,
            group: group
        ).sortedByDateTimeDescending()

        guard let last = transactions.first else {
            return "취소할 거래가 없습니다."
        }

        try transactionRepository.deleteTransaction(last, in: group)
        return "\(last.memo) 거래를 삭제했습니다"
    }
}
