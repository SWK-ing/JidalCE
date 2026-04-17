import Foundation

struct Transaction: Identifiable, Hashable {
    let id: String
    var amount: Int
    var category: String
    var memo: String
    var time: String
    var by: String
    var date: Date
    var ledgerName: String
}

struct TransactionDraft {
    var amountText = ""
    var isIncome = false
    var category = "식비"
    var memo = ""
    var time = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: .now)
    }()
    var date = Date()
    var ledgerName = ""

    var signedAmount: Int {
        let value = Int(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        return isIncome ? value : -value
    }
}

extension TransactionDraft {
    init(transaction: Transaction) {
        amountText = String(abs(transaction.amount))
        isIncome = transaction.amount > 0
        category = transaction.category
        memo = transaction.memo
        time = transaction.time
        date = transaction.date
        ledgerName = transaction.ledgerName
    }

    func makeTransaction(id: String, by: String, ledgerName: String) -> Transaction {
        Transaction(
            id: id,
            amount: signedAmount,
            category: category,
            memo: memo,
            time: time,
            by: by,
            date: date,
            ledgerName: self.ledgerName.isEmpty ? ledgerName : self.ledgerName
        )
    }
}
