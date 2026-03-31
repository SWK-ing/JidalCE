import AppIntents
import UIKit

struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "가계부 지출 기록"
    static var description = IntentDescription("음성 텍스트로 지출을 기록합니다")
    static var openAppWhenRun = false

    @Parameter(title: "내용")
    var spokenText: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await run()
        return .result(dialog: IntentDialog(stringLiteral: message))
    }

    @MainActor
    private func run() async throws -> String {
        let aiService = AIService()
        let parsed = try await aiService.parseVoiceInput(spokenText)
        guard let amount = parsed.amount, amount > 0 else {
            return "금액을 해석하지 못했습니다."
        }

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
        let transaction = Transaction(
            id: NoteSerializer.makeTransactionID(),
            amount: -(amount),
            category: parsed.category ?? "기타",
            memo: parsed.memo ?? spokenText,
            time: Date().hhmmString,
            by: UserDefaults.standard.string(forKey: "authorName") ?? UIDevice.current.name,
            date: ParsedTransactionDateResolver.resolveDate(parsed.date),
            ledgerName: ledgerName
        )
        try transactionRepository.addTransaction(transaction, in: group)
        return "\(transaction.memo) \(amount)원 기록했습니다"
    }
}
