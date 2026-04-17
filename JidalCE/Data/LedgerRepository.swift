import EventKit
import Foundation

struct LedgerRepository {
    private static let metaDate: Date = {
        ISO8601DateFormatter().date(from: "2000-01-01T00:00:00Z")!
    }()

    private let store: CalendarStore

    init(store: CalendarStore) {
        self.store = store
    }

    func fetchLedgers(in group: JidalGroup) throws -> [Ledger] {
        let calendar = try calendar(for: group)
        var names = Set<String>()

        for event in fetchMetaEvents(calendar: calendar) where store.isJidalEvent(event) {
            if event.title.hasPrefix("__meta_"), let name = parseLedgerName(fromMetaTitle: event.title) {
                names.insert(name)
            }
        }

        let recentStart = Date().addingMonth(-11).startOfMonth
        let recentEnd = Date().endOfDay
        let recentEvents = store.fetchEvents(from: recentStart, to: recentEnd, calendar: calendar)
        for event in recentEvents where store.isJidalEvent(event) && !store.isSystemEventTitle(event.title) {
            names.insert(event.title)
        }

        let ledgers = try names.sorted().enumerated().map { index, name in
            try loadLedgerMeta(name: name, calendar: calendar, fallbackSortOrder: index)
        }
        return ledgers.sorted { $0.sortOrder < $1.sortOrder }
    }

    func saveLedger(_ ledger: Ledger, in group: JidalGroup) throws {
        let calendar = try calendar(for: group)
        let normalizedLedger = Ledger(
            name: ledger.name,
            icon: ledger.icon.migratedLedgerIconName,
            color: ledger.color,
            currency: ledger.currency,
            sortOrder: ledger.sortOrder
        )
        let existingNames = try fetchLedgers(in: group).map(\.name)
        if existingMetaEvent(name: normalizedLedger.name, calendar: calendar) == nil && existingNames.contains(normalizedLedger.name) {
            throw JidalDataError.duplicateLedgerName
        }
        let event = existingMetaEvent(name: normalizedLedger.name, calendar: calendar) ?? EKEvent(eventStore: store.eventStore)
        event.calendar = calendar
        event.title = "__meta_\(normalizedLedger.name)__"
        event.startDate = ISO8601DateFormatter().date(from: "2000-01-01T00:00:00Z") ?? Date(timeIntervalSince1970: 946684800)
        event.endDate = event.startDate
        event.isAllDay = true
        event.url = store.jidalURL(for: .meta, ledgerName: normalizedLedger.name)
        event.notes = [
            "아이콘: \(normalizedLedger.icon)",
            "색상: \(normalizedLedger.color)",
            "통화: \(normalizedLedger.currency)",
            "생성일: \(Date.now.yyyyMMddString)",
            "──────────",
            "#meta:\(normalizedLedger.name)"
        ].joined(separator: "\n")
        try store.eventStore.save(event, span: .thisEvent, commit: true)
    }

    func deleteLedger(named ledgerName: String, in group: JidalGroup) throws {
        let calendar = try calendar(for: group)
        let metaTargets = fetchMetaEvents(calendar: calendar).filter {
            $0.title == "__meta_\(ledgerName)__"
        }
        let recentStart = Calendar.current.date(byAdding: .year, value: -10, to: Date())?.startOfDay ?? Date()
        let wideTargets = store.fetchEvents(from: recentStart, to: Date().endOfDay, calendar: calendar).filter {
            if $0.title == ledgerName { return true }
            return $0.title.contains(ledgerName) && store.isSystemEventTitle($0.title)
        }
        for event in metaTargets + wideTargets {
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

    private func fetchMetaEvents(calendar: EKCalendar) -> [EKEvent] {
        store.fetchEvents(
            from: Self.metaDate.startOfDay,
            to: Calendar.current.date(byAdding: .day, value: 1, to: Self.metaDate.startOfDay) ?? Self.metaDate.endOfDay,
            calendar: calendar
        )
    }

    private func existingMetaEvent(name: String, calendar: EKCalendar) -> EKEvent? {
        fetchMetaEvents(calendar: calendar)
            .first(where: { $0.title == "__meta_\(name)__" })
    }

    private func loadLedgerMeta(name: String, calendar: EKCalendar, fallbackSortOrder: Int) throws -> Ledger {
        guard let event = existingMetaEvent(name: name, calendar: calendar), let notes = event.notes else {
            return Ledger(name: name, icon: "wonsign.circle.fill", color: "blue", currency: "KRW", sortOrder: fallbackSortOrder)
        }

        var icon = "wonsign.circle.fill"
        var color = "blue"
        var currency = "KRW"
        for line in notes.split(separator: "\n").map(String.init) {
            if line.hasPrefix("아이콘: ") {
                icon = String(line.dropFirst("아이콘: ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if line.hasPrefix("색상: ") {
                color = String(line.dropFirst("색상: ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if line.hasPrefix("통화: ") {
                currency = String(line.dropFirst("통화: ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        let migratedIcon = icon.migratedLedgerIconName
        if migratedIcon != icon {
            event.notes = notes.replacingOccurrences(of: "아이콘: \(icon)", with: "아이콘: \(migratedIcon)")
            try store.eventStore.save(event, span: .thisEvent, commit: true)
        }
        return Ledger(name: name, icon: migratedIcon, color: color, currency: currency, sortOrder: fallbackSortOrder)
    }

    private func parseLedgerName(fromMetaTitle title: String) -> String? {
        guard title.hasPrefix("__meta_"), title.hasSuffix("__") else { return nil }
        return String(title.dropFirst("__meta_".count).dropLast(2))
    }
}
