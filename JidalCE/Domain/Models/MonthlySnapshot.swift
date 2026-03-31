struct MonthlySnapshot: Hashable {
    let yearMonth: String
    let carryOver: Int
    let totalIncome: Int
    let totalExpense: Int
    let closingBalance: Int
}
