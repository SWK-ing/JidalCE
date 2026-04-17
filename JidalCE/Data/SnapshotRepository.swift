import EventKit
import Foundation

struct SnapshotRepository {
    private let store: CalendarStore
    private let transactionRepository: TransactionRepository

    init(store: CalendarStore, transactionRepository: TransactionRepository) {
        self.store = store
        self.transactionRepository = transactionRepository
    }

    func ensureAutomaticSnapshot(for ledgerName: String, in group: JidalGroup) throws {
        let targetMonth = Date().addingMonth(-2).startOfMonth
        guard latestSnapshot(for: targetMonth.yearMonthString, ledgerName: ledgerName, in: group) == nil else { return }
        try createSnapshot(for: targetMonth, ledgerName: ledgerName, in: group)
    }

    func rebuildSnapshots(ledgerName: String, in group: JidalGroup, startingFrom startDate: Date) throws {
        try rebuildSnapshots(ledgerName: ledgerName, in: group, startingFrom: startDate) { _ in }
    }

    func rebuildSnapshots(ledgerName: String, in group: JidalGroup, startingFrom startDate: Date, progress: (Date) throws -> Void) throws {
        let calendar = try calendar(for: group)
        let endMonth = Date().addingMonth(-2).startOfMonth
        let snapshots = store.fetchEvents(from: startDate.startOfMonth, to: endMonth.endOfMonth.addingMonth(1), calendar: calendar)
            .filter { $0.title == "__snapshot_\(ledgerName)__" }
        for event in snapshots {
            try store.eventStore.remove(event, span: .thisEvent, commit: false)
        }
        try store.eventStore.commit()

        var month = startDate.startOfMonth
        while month <= endMonth {
            try createSnapshot(for: month, ledgerName: ledgerName, in: group)
            try progress(month)
            month = month.addingMonth(1)
        }
    }

    func latestSnapshot(before date: Date, ledgerName: String, in group: JidalGroup) throws -> MonthlySnapshot? {
        let calendar = try calendar(for: group)
        let endDate = Calendar.current.date(byAdding: .second, value: -1, to: date) ?? date
        let startDate = Calendar.current.date(byAdding: .year, value: -10, to: endDate)?.startOfDay ?? endDate.startOfDay
        return store.fetchEvents(from: startDate, to: endDate, calendar: calendar)
            .filter { $0.title == "__snapshot_\(ledgerName)__" }
            .compactMap(parseSnapshot)
            .sorted { $0.yearMonth < $1.yearMonth }
            .last
    }

    func latestSnapshot(for yearMonth: String, ledgerName: String, in group: JidalGroup) -> MonthlySnapshot? {
        guard
            let calendar = try? calendar(for: group),
            let monthDate = yearMonth.firstDateFromYearMonth
        else { return nil }

        let snapshotDate = monthDate.addingMonth(1).startOfMonth
        return store.fetchEvents(from: snapshotDate.startOfDay, to: snapshotDate.endOfDay, calendar: calendar)
            .filter { $0.title == "__snapshot_\(ledgerName)__" }
            .compactMap(parseSnapshot)
            .first(where: { $0.yearMonth == yearMonth })
    }

    func detectFirstRecordDate(in group: JidalGroup) -> Date? {
        guard let calendar = try? calendar(for: group) else { return nil }
        let startDate = Calendar.current.date(byAdding: .year, value: -10, to: Date())?.startOfDay ?? Date().startOfDay
        return store.fetchEvents(from: startDate, to: Date().endOfDay, calendar: calendar)
            .filter { !store.isSystemEventTitle($0.title) && store.isJidalEvent($0) }
            .map(\.startDate)
            .min()
    }

    private func createSnapshot(for month: Date, ledgerName: String, in group: JidalGroup) throws {
        let calendar = try calendar(for: group)
        let previous = try latestSnapshot(
            before: month.addingMonth(1).startOfMonth,
            ledgerName: ledgerName,
            in: group
        )
        let carryOver = previous?.closingBalance ?? 0
        let transactions = try transactionRepository.fetchTransactions(from: month.startOfMonth, to: month.endOfMonth, ledgerName: ledgerName, group: group)
        let income = transactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let expense = transactions.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
        let closing = carryOver + income - expense

        let event = existingSnapshotEvent(for: month, ledgerName: ledgerName, calendar: calendar) ?? EKEvent(eventStore: store.eventStore)
        event.calendar = calendar
        event.title = "__snapshot_\(ledgerName)__"
        event.startDate = month.addingMonth(1).startOfMonth
        event.endDate = event.startDate
        event.isAllDay = true
        event.url = store.jidalURL(for: .snapshot, ledgerName: ledgerName)
        event.notes = [
            "── \(month.monthDisplayText) 마감 ──",
            "이월: \(carryOver.wonString)",
            "수입: \(income.wonString)",
            "지출: \(expense.wonString)",
            "잔액: \(closing.wonString)",
            "──────────",
            "#snapshot:\(month.yearMonthString)"
        ].joined(separator: "\n")
        try store.eventStore.save(event, span: .thisEvent, commit: true)
    }

    private func existingSnapshotEvent(for month: Date, ledgerName: String, calendar: EKCalendar) -> EKEvent? {
        let snapshotDate = month.addingMonth(1).startOfMonth
        return store.fetchEvents(from: snapshotDate.startOfDay, to: snapshotDate.endOfDay, calendar: calendar)
            .first { $0.title == "__snapshot_\(ledgerName)__" }
    }

    private func parseSnapshot(event: EKEvent) -> MonthlySnapshot? {
        parseSnapshot(notes: event.notes)
    }

    private func parseSnapshot(notes: String?) -> MonthlySnapshot? {
        guard let notes else { return nil }
        let lines = notes.split(separator: "\n").map(String.init)
        guard
            let carryLine = lines.first(where: { $0.hasPrefix("이월:") }),
            let incomeLine = lines.first(where: { $0.hasPrefix("수입:") }),
            let expenseLine = lines.first(where: { $0.hasPrefix("지출:") }),
            let balanceLine = lines.first(where: { $0.hasPrefix("잔액:") }),
            let idLine = lines.first(where: { $0.hasPrefix("#snapshot:") })
        else { return nil }

        return MonthlySnapshot(
            yearMonth: String(idLine.dropFirst("#snapshot:".count)),
            carryOver: parseWon(carryLine),
            totalIncome: parseWon(incomeLine),
            totalExpense: parseWon(expenseLine),
            closingBalance: parseWon(balanceLine)
        )
    }

    private func parseWon(_ line: String) -> Int {
        Int(line.components(separatedBy: ":").last?
            .replacingOccurrences(of: "원", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
    }

    private func calendar(for group: JidalGroup) throws -> EKCalendar {
        guard let calendar = store.eventStore.calendar(withIdentifier: group.id) else {
            throw JidalDataError.calendarNotFound
        }
        return calendar
    }
}
