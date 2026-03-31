import Foundation

struct BalanceCalculator {
    let transactionRepository: TransactionRepository
    let snapshotRepository: SnapshotRepository

    func currentBalance(ledgerName: String, in group: JidalGroup, anchorDate: Date) throws -> Int {
        let snapshot = try snapshotRepository.latestSnapshot(before: anchorDate.startOfMonth, ledgerName: ledgerName, in: group)
        let snapshotBalance = snapshot?.closingBalance ?? 0
        let snapshotStart = snapshot?.yearMonth.firstDateFromYearMonth?.addingMonth(1) ?? Date.distantPast
        let liveTransactions = try transactionRepository.fetchTransactions(
            from: snapshotStart,
            to: anchorDate.endOfMonth,
            ledgerName: ledgerName,
            group: group
        )
        return snapshotBalance + liveTransactions.reduce(0) { $0 + $1.amount }
    }
}
