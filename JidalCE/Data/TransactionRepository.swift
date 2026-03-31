import EventKit
import Foundation

struct TransactionRepository {
    private let store: CalendarStore
    private let historyRepository: HistoryRepository

    init(store: CalendarStore, historyRepository: HistoryRepository) {
        self.store = store
        self.historyRepository = historyRepository
    }

    func addTransaction(_ transaction: Transaction, in group: JidalGroup) throws {
        let calendar = try calendar(for: group)
        let event = existingTransactionEvent(on: transaction.date, ledgerName: transaction.ledgerName, calendar: calendar)
            ?? makeTransactionEvent(for: transaction, calendar: calendar)
        let refreshedEvent = store.refreshedEvent(from: event)

        var records = try NoteSerializer.parse(refreshedEvent.notes)
        let uniqueID = nextTransactionID(existingIDs: Set(records.map(\.id)))
        let savedTransaction = uniqueID == transaction.id ? transaction : Transaction(
            id: uniqueID,
            amount: transaction.amount,
            category: transaction.category,
            memo: transaction.memo,
            time: transaction.time,
            by: transaction.by,
            date: transaction.date,
            ledgerName: transaction.ledgerName
        )
        records.append(record(from: savedTransaction))
        refreshedEvent.notes = NoteSerializer.serialize(records: records)
        try store.eventStore.save(refreshedEvent, span: .thisEvent, commit: true)
        try historyRepository.appendEntry(for: savedTransaction, action: .added, in: group)
    }

    func updateTransaction(original: Transaction, updated: Transaction, in group: JidalGroup) throws {
        let calendar = try calendar(for: group)
        guard let sourceEvent = eventContainingTransaction(original, calendar: calendar) else {
            throw JidalDataError.transactionEventNotFound
        }
        let refreshedSource = store.refreshedEvent(from: sourceEvent)
        var sourceRecords = try NoteSerializer.parse(refreshedSource.notes)
        guard let sourceIndex = sourceRecords.firstIndex(where: { $0.id == original.id }) else {
            throw JidalDataError.transactionEventNotFound
        }

        let previousAmount = sourceRecords[sourceIndex].amount
        let sameBucket = Calendar.current.isDate(original.date, inSameDayAs: updated.date) && original.ledgerName == updated.ledgerName

        if sameBucket {
            sourceRecords[sourceIndex] = record(from: updated)
            refreshedSource.notes = NoteSerializer.serialize(records: sourceRecords)
            try store.eventStore.save(refreshedSource, span: .thisEvent, commit: true)
        } else {
            sourceRecords.remove(at: sourceIndex)
            if sourceRecords.isEmpty {
                try store.eventStore.remove(refreshedSource, span: .thisEvent, commit: false)
            } else {
                refreshedSource.notes = NoteSerializer.serialize(records: sourceRecords)
                try store.eventStore.save(refreshedSource, span: .thisEvent, commit: false)
            }

            let targetEvent = existingTransactionEvent(on: updated.date, ledgerName: updated.ledgerName, calendar: calendar)
                ?? makeTransactionEvent(for: updated, calendar: calendar)
            let refreshedTarget = store.refreshedEvent(from: targetEvent)
            var targetRecords = try NoteSerializer.parse(refreshedTarget.notes)
            targetRecords.append(record(from: updated))
            refreshedTarget.notes = NoteSerializer.serialize(records: targetRecords)
            try store.eventStore.save(refreshedTarget, span: .thisEvent, commit: false)
            try store.eventStore.commit()
        }

        try historyRepository.appendEntry(for: updated, action: .modified, previousAmount: previousAmount, in: group)
    }

    func deleteTransaction(_ transaction: Transaction, in group: JidalGroup, addHistory: Bool = true) throws {
        let calendar = try calendar(for: group)
        guard let event = eventContainingTransaction(transaction, calendar: calendar) else {
            throw JidalDataError.transactionEventNotFound
        }

        var records = try NoteSerializer.parse(event.notes)
        records.removeAll { $0.id == transaction.id }
        if records.isEmpty {
            try store.eventStore.remove(event, span: .thisEvent, commit: true)
        } else {
            event.notes = NoteSerializer.serialize(records: records)
            try store.eventStore.save(event, span: .thisEvent, commit: true)
        }
        if addHistory {
            try historyRepository.appendEntry(for: transaction, action: .deleted, in: group)
        }
    }

    func fetchTransactions(inMonth month: Date, ledgerName: String, group: JidalGroup) throws -> [Transaction] {
        try fetchTransactions(from: month.startOfMonth, to: month.endOfMonth, ledgerName: ledgerName, group: group)
    }

    func fetchTransactions(from start: Date, to end: Date, ledgerName: String, group: JidalGroup) throws -> [Transaction] {
        let calendar = try calendar(for: group)
        return store.fetchEvents(from: start, to: end, calendar: calendar)
            .filter {
                $0.title == ledgerName &&
                !$0.title.isEmpty &&
                !store.isSystemEventTitle($0.title) &&
                store.isJidalEvent($0)
            }
            .flatMap { event in
                (try? NoteSerializer.parse(event.notes))?.map { record in
                    Transaction(
                        id: record.id,
                        amount: record.amount,
                        category: record.category,
                        memo: record.memo,
                        time: record.time,
                        by: record.by,
                        date: event.startDate,
                        ledgerName: ledgerName
                    )
                } ?? []
            }
    }

    private func eventContainingTransaction(_ transaction: Transaction, calendar: EKCalendar) -> EKEvent? {
        store.fetchEvents(from: transaction.date.startOfDay, to: transaction.date.endOfDay, calendar: calendar)
            .first(where: { event in
                guard event.title == transaction.ledgerName else { return false }
                let records = (try? NoteSerializer.parse(event.notes)) ?? []
                return records.contains(where: { $0.id == transaction.id })
            })
    }

    private func existingTransactionEvent(on date: Date, ledgerName: String, calendar: EKCalendar) -> EKEvent? {
        store.fetchEvents(from: date.startOfDay, to: date.endOfDay, calendar: calendar)
            .first {
                $0.title == ledgerName &&
                !$0.title.isEmpty &&
                !store.isSystemEventTitle($0.title) &&
                store.isJidalEvent($0)
            }
    }

    private func makeTransactionEvent(for transaction: Transaction, calendar: EKCalendar) -> EKEvent {
        let event = EKEvent(eventStore: store.eventStore)
        event.calendar = calendar
        event.title = transaction.ledgerName
        event.startDate = transaction.date.startOfDay
        event.endDate = event.startDate
        event.isAllDay = true
        event.url = store.jidalURL(for: .transaction, ledgerName: transaction.ledgerName)
        return event
    }

    private func record(from transaction: Transaction) -> TransactionRecord {
        TransactionRecord(
            id: transaction.id,
            amount: transaction.amount,
            category: transaction.category,
            memo: transaction.memo,
            time: transaction.time,
            by: transaction.by
        )
    }

    private func nextTransactionID(existingIDs: Set<String>) -> String {
        var identifier = NoteSerializer.makeTransactionID()
        while existingIDs.contains(identifier) {
            identifier = NoteSerializer.makeTransactionID()
        }
        return identifier
    }

    private func calendar(for group: JidalGroup) throws -> EKCalendar {
        guard let calendar = store.eventStore.calendar(withIdentifier: group.id) else {
            throw JidalDataError.calendarNotFound
        }
        return calendar
    }
}
