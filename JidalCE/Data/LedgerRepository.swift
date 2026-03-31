import EventKit
import Foundation

struct LedgerRepository {
    private let store: CalendarStore

    init(store: CalendarStore) {
        self.store = store
    }

    func fetchLedgers(in group: JidalGroup) throws -> [Ledger] {
        let calendar = try calendar(for: group)
        let events = store.fetchEvents(from: Date.distantPast, to: Date.distantFuture, calendar: calendar)
        var names = Set<String>()
        for event in events where store.isJidalEvent(event) {
            if store.isSystemEventTitle(event.title) {
                if event.title.hasPrefix("__meta_"), let name = parseLedgerName(fromMetaTitle: event.title) {
                    names.insert(name)
                }
            } else {
                names.insert(event.title)
            }
        }

        let ledgers = names.sorted().enumerated().map { index, name in
            loadLedgerMeta(name: name, calendar: calendar, fallbackSortOrder: index)
        }
        return ledgers.sorted { $0.sortOrder < $1.sortOrder }
    }

    func saveLedger(_ ledger: Ledger, in group: JidalGroup) throws {
        let calendar = try calendar(for: group)
        let existingNames = try fetchLedgers(in: group).map(\.name)
        if existingMetaEvent(name: ledger.name, calendar: calendar) == nil && existingNames.contains(ledger.name) {
            throw JidalDataError.duplicateLedgerName
        }
        let event = existingMetaEvent(name: ledger.name, calendar: calendar) ?? EKEvent(eventStore: store.eventStore)
        event.calendar = calendar
        event.title = "__meta_\(ledger.name)__"
        event.startDate = ISO8601DateFormatter().date(from: "2000-01-01T00:00:00Z") ?? Date(timeIntervalSince1970: 946684800)
        event.endDate = event.startDate
        event.isAllDay = true
        event.url = store.jidalURL(for: .meta, ledgerName: ledger.name)
        event.notes = [
            "아이콘: \(ledger.icon)",
            "색상: \(ledger.color)",
            "통화: \(ledger.currency)",
            "생성일: \(Date.now.yyyyMMddString)",
            "──────────",
            "#meta:\(ledger.name)"
        ].joined(separator: "\n")
        try store.eventStore.save(event, span: .thisEvent, commit: true)
    }

    func deleteLedger(named ledgerName: String, in group: JidalGroup) throws {
        let calendar = try calendar(for: group)
        let events = store.fetchEvents(from: Date.distantPast, to: Date.distantFuture, calendar: calendar)
        let targets = events.filter {
            if $0.title == ledgerName { return true }
            return $0.title.contains(ledgerName) && store.isSystemEventTitle($0.title)
        }
        for event in targets {
            try store.eventStore.remove(event, span: .thisEvent, commit: false)
        }
        try store.eventStore.commit()
    }

    private func calendar(for group: JidalGroup) throws -> EKCalendar {
        guard let calendar = store.eventStore.calendar(withIdentifier: group.id) else {
            throw JidalDataError.calendarNotFound
        }
        return calendar
    }

    private func existingMetaEvent(name: String, calendar: EKCalendar) -> EKEvent? {
        store.fetchEvents(from: Date.distantPast, to: Date.distantFuture, calendar: calendar)
            .first(where: { $0.title == "__meta_\(name)__" })
    }

    private func loadLedgerMeta(name: String, calendar: EKCalendar, fallbackSortOrder: Int) -> Ledger {
        guard
            let notes = existingMetaEvent(name: name, calendar: calendar)?.notes
        else {
            return Ledger(name: name, icon: "💰", color: "blue", currency: "KRW", sortOrder: fallbackSortOrder)
        }

        var icon = "💰"
        var color = "blue"
        var currency = "KRW"
        for line in notes.split(separator: "\n").map(String.init) {
            if line.hasPrefix("아이콘: ") { icon = String(line.dropFirst(4)) }
            if line.hasPrefix("색상: ") { color = String(line.dropFirst(4)) }
            if line.hasPrefix("통화: ") { currency = String(line.dropFirst(4)) }
        }
        return Ledger(name: name, icon: icon, color: color, currency: currency, sortOrder: fallbackSortOrder)
    }

    private func parseLedgerName(fromMetaTitle title: String) -> String? {
        guard title.hasPrefix("__meta_"), title.hasSuffix("__") else { return nil }
        return String(title.dropFirst("__meta_".count).dropLast(2))
    }
}
