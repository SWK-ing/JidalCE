import EventKit
import Foundation

enum JidalDataError: LocalizedError {
    case calendarNotFound
    case noICloudSource
    case invalidGroupName
    case ledgerNotSelected
    case transactionEventNotFound
    case duplicateLedgerName

    var errorDescription: String? {
        switch self {
        case .calendarNotFound:
            return "캘린더를 찾을 수 없습니다."
        case .noICloudSource:
            return "iCloud 캘린더 소스를 찾을 수 없습니다."
        case .invalidGroupName:
            return "그룹 이름을 입력하세요."
        case .ledgerNotSelected:
            return "가계부를 먼저 선택하세요."
        case .transactionEventNotFound:
            return "거래 이벤트를 찾을 수 없습니다."
        case .duplicateLedgerName:
            return "같은 이름의 가계부가 이미 있습니다."
        }
    }
}

struct GroupRepository {
    private let store: CalendarStore
    private let selectedGroupKey = "selectedGroupIdentifier"
    private let selectedLedgerKey = "selectedLedgerName"

    init(store: CalendarStore) {
        self.store = store
    }

    func fetchGroups() -> [JidalGroup] {
        store.eventStore.calendars(for: .event).map {
            JidalGroup(id: $0.calendarIdentifier, name: $0.title, color: $0.cgColor)
        }
        .sorted { $0.name < $1.name }
    }

    func restoreSelectedGroup(from groups: [JidalGroup]) -> JidalGroup? {
        guard let id = UserDefaults.standard.string(forKey: selectedGroupKey) else {
            return groups.first
        }
        return groups.first(where: { $0.id == id }) ?? groups.first
    }

    func persistSelectedGroup(_ identifier: String) {
        UserDefaults.standard.set(identifier, forKey: selectedGroupKey)
    }

    func persistSelectedLedger(_ ledgerName: String?) {
        UserDefaults.standard.set(ledgerName, forKey: selectedLedgerKey)
    }

    func restoreSelectedLedger(from ledgers: [Ledger]) -> String? {
        guard let name = UserDefaults.standard.string(forKey: selectedLedgerKey) else {
            return ledgers.first?.name
        }
        return ledgers.contains(where: { $0.name == name }) ? name : ledgers.first?.name
    }

    func createGroup(name: String, color: CGColor) throws -> JidalGroup {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw JidalDataError.invalidGroupName }
        guard let source = store.eventStore.sources.first(where: { $0.sourceType == .calDAV }) ??
                store.eventStore.defaultCalendarForNewEvents?.source else {
            throw JidalDataError.noICloudSource
        }

        let calendar = EKCalendar(for: .event, eventStore: store.eventStore)
        calendar.title = trimmed
        calendar.cgColor = color
        calendar.source = source
        try store.eventStore.saveCalendar(calendar, commit: true)

        return JidalGroup(id: calendar.calendarIdentifier, name: trimmed, color: color)
    }

    func deleteGroup(_ group: JidalGroup) throws {
        guard let calendar = store.eventStore.calendar(withIdentifier: group.id) else {
            throw JidalDataError.calendarNotFound
        }
        try store.eventStore.removeCalendar(calendar, commit: true)
    }

    func renameGroup(_ group: JidalGroup, to newName: String) throws -> JidalGroup {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw JidalDataError.invalidGroupName }
        guard let calendar = store.eventStore.calendar(withIdentifier: group.id) else {
            throw JidalDataError.calendarNotFound
        }
        calendar.title = trimmed
        try store.eventStore.saveCalendar(calendar, commit: true)
        return JidalGroup(id: calendar.calendarIdentifier, name: calendar.title, color: calendar.cgColor)
    }
}
