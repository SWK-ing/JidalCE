import EventKit
import Foundation

struct HistoryRepository {
    private let store: CalendarStore
    private let maxNotesSize = 50_000

    init(store: CalendarStore) {
        self.store = store
    }

    func appendEntry(for transaction: Transaction, action: HistoryAction, previousAmount: Int? = nil, in group: JidalGroup) throws {
        let calendar = try calendar(for: group)
        let yearMonth = transaction.date.yearMonthString
        let entry = makeEntry(for: transaction, action: action, previousAmount: previousAmount)
        let events = historyEvents(ledgerName: transaction.ledgerName, yearMonth: yearMonth, calendar: calendar)
        let target = events.last ?? makeHistoryEvent(ledgerName: transaction.ledgerName, yearMonth: yearMonth, suffix: nil, calendar: calendar)
        let refreshedTarget = store.refreshedEvent(from: target)
        var currentEntries = HistorySerializer.parse(refreshedTarget.notes)
        currentEntries.append(entry)
        let serialized = HistorySerializer.serialize(entries: currentEntries, monthText: transaction.date.monthDisplayText, yearMonth: yearMonth)

        if serialized.utf8.count > maxNotesSize && !currentEntries.dropLast().isEmpty {
            let suffix = nextSuffix(for: events.count + 1)
            let splitEvent = makeHistoryEvent(ledgerName: transaction.ledgerName, yearMonth: yearMonth, suffix: suffix, calendar: calendar)
            splitEvent.notes = HistorySerializer.serialize(entries: [entry], monthText: transaction.date.monthDisplayText, yearMonth: yearMonth)
            try store.eventStore.save(splitEvent, span: .thisEvent, commit: true)
        } else {
            refreshedTarget.notes = serialized
            try store.eventStore.save(refreshedTarget, span: .thisEvent, commit: true)
        }
    }

    func fetchRecentEntries(ledgerName: String, group: JidalGroup, anchorMonth: Date) throws -> [HistoryEntry] {
        let calendar = try calendar(for: group)
        let months = [anchorMonth, anchorMonth.addingMonth(-1)].map(\.yearMonthString)
        let entries = try months.flatMap { yearMonth in
            try loadEntries(ledgerName: ledgerName, yearMonth: yearMonth, calendar: calendar)
                .map { (entry: $0, sortDate: historySortDate(for: $0, yearMonth: yearMonth) ?? .distantPast) }
        }
        return entries
            .sorted { $0.sortDate > $1.sortDate }
            .prefix(30)
            .map(\.entry)
    }

    private func loadEntries(ledgerName: String, yearMonth: String, calendar: EKCalendar) throws -> [HistoryEntry] {
        historyEvents(ledgerName: ledgerName, yearMonth: yearMonth, calendar: calendar)
            .flatMap { HistorySerializer.parse($0.notes) }
    }

    private func historyEvents(ledgerName: String, yearMonth: String, calendar: EKCalendar) -> [EKEvent] {
        let prefix = "__history_\(ledgerName)_\(yearMonth)"
        return store.fetchEvents(from: yearMonth.firstDateFromYearMonth ?? Date.distantPast, to: (yearMonth.firstDateFromYearMonth ?? Date()).endOfMonth, calendar: calendar)
            .filter { $0.title.hasPrefix(prefix) }
            .sorted { $0.title < $1.title }
    }

    private func makeHistoryEvent(ledgerName: String, yearMonth: String, suffix: String?, calendar: EKCalendar) -> EKEvent {
        let event = EKEvent(eventStore: store.eventStore)
        let base = "__history_\(ledgerName)_\(yearMonth)"
        event.title = suffix.map { "\(base)-\($0)__" } ?? "\(base)__"
        event.calendar = calendar
        event.startDate = yearMonth.firstDateFromYearMonth ?? Date()
        event.endDate = event.startDate
        event.isAllDay = true
        event.url = store.jidalURL(for: .history, ledgerName: ledgerName)
        return event
    }

    private func nextSuffix(for count: Int) -> String {
        let scalarValue = 65 + count - 1
        return String(UnicodeScalar(scalarValue) ?? UnicodeScalar(66))
    }

    private func makeEntry(for transaction: Transaction, action: HistoryAction, previousAmount: Int?) -> HistoryEntry {
        let amountText: String
        if let previousAmount {
            amountText = "\(NoteSerializer.signedAmountString(previousAmount))원→\(NoteSerializer.signedAmountString(transaction.amount))원"
        } else {
            amountText = "\(NoteSerializer.signedAmountString(transaction.amount))원"
        }
        return HistoryEntry(
            date: transaction.date.monthDayHistoryString,
            time: transaction.time,
            action: action,
            memo: transaction.memo,
            amount: amountText,
            by: transaction.by
        )
    }

    private func historySortDate(for entry: HistoryEntry, yearMonth: String) -> Date? {
        let day = entry.date.components(separatedBy: "/").last ?? "01"
        let dateTime = "\(yearMonth)-\(day) \(entry.time)"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: dateTime)
    }

    private func calendar(for group: JidalGroup) throws -> EKCalendar {
        guard let calendar = store.eventStore.calendar(withIdentifier: group.id) else {
            throw JidalDataError.calendarNotFound
        }
        return calendar
    }
}
