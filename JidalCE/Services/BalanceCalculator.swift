import Foundation

struct BalanceCalculator {
    let transactionRepository: TransactionRepository
    let snapshotRepository: SnapshotRepository

    func currentBalance(ledgerName: String, in group: JidalGroup, anchorDate: Date) throws -> Int {
        let snapshot = try snapshotRepository.latestSnapshot(
            before: anchorDate.startOfMonth.addingMonth(1),
            ledgerName: ledgerName,
            in: group
        )
        let snapshotBalance = snapshot?.closingBalance ?? 0
        let snapshotStart = snapshot?.yearMonth.firstDateFromYearMonth?.addingMonth(1)
            ?? (Calendar.current.date(byAdding: .year, value: -10, to: anchorDate)?.startOfDay ?? anchorDate.startOfDay)
        let liveTransactions = try transactionRepository.fetchTransactions(
            from: snapshotStart,
            to: anchorDate.endOfMonth,
            ledgerName: ledgerName,
            group: group
        )
        return snapshotBalance + liveTransactions.reduce(0) { $0 + $1.amount }
    }
}
