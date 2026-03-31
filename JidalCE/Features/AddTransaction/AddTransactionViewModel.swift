import Foundation

@MainActor
@Observable
final class AddTransactionViewModel {
    let appState: AppState
    let editingTransaction: Transaction?
    var draft: TransactionDraft

    init(appState: AppState, editingTransaction: Transaction? = nil) {
        self.appState = appState
        self.editingTransaction = editingTransaction
        self.draft = editingTransaction.map(TransactionDraft.init) ?? TransactionDraft(
            amountText: "",
            isIncome: false,
            category: appState.categoryManager.categories.first ?? "식비",
            memo: "",
            time: Date.now.hhmmString,
            date: Date(),
            ledgerName: appState.selectedLedgerName ?? ""
        )
    }

    var titleText: String {
        editingTransaction == nil ? "거래 추가" : "거래 수정"
    }

    func applyParsedResult(_ result: AIService.ParsedResult) {
        if let amount = result.amount {
            draft.amountText = String(amount)
        }
        draft.isIncome = result.type == "수입"
        if let category = result.category, appState.categoryManager.categories.contains(category) {
            draft.category = category
        } else if result.category == "기타" {
            draft.category = "기타"
        }
        if let memo = result.memo {
            draft.memo = memo
        }
        draft.date = ParsedTransactionDateResolver.resolveDate(result.date)
    }

    func save() async {
        if let editingTransaction {
            await appState.updateTransaction(editingTransaction, with: draft)
        } else {
            await appState.addTransaction(draft)
        }
    }
}
